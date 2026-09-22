# Bug Report: Segmentation Fault in `COTAN::calculatePValue()` due to `dspMatrix` Integer Overflow

## Status
* **Severity**: Critical (Aborts R session)
* **Target Package**: `COTAN` (source code location: `COTAN/R/genesStatistics.R`)
* **Trigger Condition**: Running genome-wide `calculatePValue()` on a dataset with a large number of genes ($N \ge 46,341$) such that $N^2 \ge 2^{31} - 1$.
* **Workaround**: Reduce the dataset size to $< 41,000$ features, or modify the indexing logic to bypass the `Matrix` package subscript operator.

---

## 1. Traceback Analysis

The segmentation fault occurs during subsetting of the co-expression statistic matrix `S`:

```
 *** caught segfault ***
address 0x7290797864e8, cause 'memory not mapped'

Traceback:
 1: ..subscript.2ary(x, l[[1L]], l[[2L]], drop = drop[1L])
 2: .subscript.2ary(x, , j, drop = drop)
 3: S[, geneBatch, drop = FALSE]
 4: S[, geneBatch, drop = FALSE]
 5: as.matrix(S[, geneBatch, drop = FALSE])
 ...
 11: lapply(genesBatches, worker, S = S)
 12: runPValueCalc(genesBatches = spGenes, S = S, cores = cores)
 13: .calculatePValueImpl(...)
 14: COTAN::calculatePValue(cotan_obj, ...)
```

The crash happens at line 359 of `COTAN/R/genesStatistics.R`:
```R
subPVals <- as.matrix(S[, geneBatch, drop = FALSE])
```

---

## 2. Root Cause: Integer Overflow in `Matrix` Package Subsetting

### A. The Object Classes
* `S` is calculated as `coex^2L * getNumCells(objCOTAN)`.
* Since `coex` is a packed symmetric matrix of class `dspMatrix`, `S` is also a `dspMatrix`.
* For $N$ genes, a `dspMatrix` stores only the upper or lower triangle in a 1D numeric vector slot `@x` of length $\frac{N(N+1)}{2}$.

### B. Index Calculation & The 32-bit Integer Limit
To subset a batch of columns from the packed symmetric representation `S`, R's `Matrix` package calls C-level subsetting code (`..subscript.2ary`). 

To locate the element at row $i$ and column $j$ (where $i \ge j$), the indexing logic calculates:
$$\text{offset} = (j - 1) \times N - \frac{(j - 1) \times j}{2} + i$$

In the compiled C code of the `Matrix` package, this indexing arithmetic is done using standard **32-bit signed integers**, which have a maximum value of $2^{31} - 1 = 2,147,483,647$.

### C. The Overflow Event
* With $N = 53,000$ genes, when the loop reaches column batches near the end of the genome (e.g., $j = 46,000$):
  $$\text{Term} = (j - 1) \times N = 45,999 \times 53,000 = 2,437,947,000$$
* Since $2,437,947,000 > 2,147,483,647$, the calculation **overflows** the signed 32-bit integer boundary.
* In computer arithmetic, this overflow wraps around to a **negative value** (e.g., $-1,857,020,296$).
* The C code then attempts to address the underlying matrix array using this corrupted negative offset, accessing unmapped memory.
* Result: System sends a SIGSEGV signal, terminating R instantly (`address ..., cause 'memory not mapped'`).

---

## 3. Recommended Code Modification

To make `COTAN` robust to large matrices of any size, the subscript operator `[` should not be used directly on `dspMatrix` / `dsyMatrix` objects when dimensions are large. Instead, we can bypass the `Matrix` package subscript operator and extract columns directly from the `@x` vector using double precision (64-bit float) calculations to avoid overflow.

### Proposed Helper Function:
Add the following function in `COTAN/R/genesStatistics.R`:

```R
safe_subset_matrix <- function(S, geneBatch) {
  if (inherits(S, "dspMatrix")) {
    N <- nrow(S)
    j_indices <- if (is.character(geneBatch)) match(geneBatch, colnames(S)) else geneBatch
    col_list <- lapply(j_indices, function(j) {
      col_vec <- numeric(N)
      j_double <- as.double(j)
      N_double <- as.double(N)
      
      # 1. Lower part (i >= j)
      i_lower <- j:N
      idx_lower <- (j_double - 1) * N_double - (j_double - 1) * j_double / 2 + i_lower
      col_vec[i_lower] <- S@x[idx_lower]
      
      # 2. Upper part (i < j) symmetric mapping
      if (j > 1) {
        i_upper <- 1:(j - 1)
        i_double <- as.double(i_upper)
        idx_upper <- (i_double - 1) * N_double - (i_double - 1) * i_double / 2 + j_double
        col_vec[i_upper] <- S@x[idx_upper]
      }
      return(col_vec)
    })
    res <- do.call(cbind, col_list)
    rownames(res) <- rownames(S)
    colnames(res) <- colnames(S)[j_indices]
    return(res)
  } else if (inherits(S, "dsyMatrix")) {
    N <- nrow(S)
    j_indices <- if (is.character(geneBatch)) match(geneBatch, colnames(S)) else geneBatch
    col_list <- lapply(j_indices, function(j) {
      j_double <- as.double(j)
      N_double <- as.double(N)
      idx <- (j_double - 1) * N_double + (1:N)
      return(S@x[idx])
    })
    res <- do.call(cbind, col_list)
    rownames(res) <- rownames(S)
    colnames(res) <- colnames(S)[j_indices]
    return(res)
  } else {
    return(as.matrix(S[, geneBatch, drop = FALSE]))
  }
}
```

### Applied Fix in `runPValueCalc`:
Replace lines 355–368 in `COTAN/R/genesStatistics.R`:

```diff
-  worker <- function(geneBatch, S) {
-    tryCatch({
-
-      ## slice columns (single read avoids copying the rest)
-      subPVals <- as.matrix(S[, geneBatch, drop = FALSE])
-
-      ## 3. p-value of χ²₁ for each entry
-      subPVals <- stats::pchisq(subPVals, df = 1L, lower.tail = FALSE)
-
-      return(subPVals)
-    }, error = function(e) {
-      structure(list(e), class = "try-error")
-    })
-  }
+  worker <- function(geneBatch, S) {
+    tryCatch({
+      # Bypasses the Matrix package subsetting bug using safe double indexing
+      subPVals <- safe_subset_matrix(S, geneBatch)
+      subPVals <- stats::pchisq(subPVals, df = 1L, lower.tail = FALSE)
+      return(subPVals)
+    }, error = function(e) {
+      structure(list(e), class = "try-error")
+    })
+  }
```
