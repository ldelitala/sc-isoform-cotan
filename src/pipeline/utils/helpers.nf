// utils/helpers.nf

def require(condition: boolean, errorMessage: String) {
    if (!condition) {
        error("\033[0;31mPipeline Validation Error: ${errorMessage}\033[0m")
    }
}

def ensureDir(paths, context: String = "directory") {
    // Convert single strings/paths to a list for uniform processing
    def dirList = paths instanceof List ? paths : [paths]

    dirList.each { d ->
        if (d) {
            def parent = file(d).getParent()
            parent?.mkdirs()
            require(parent?.exists(), "Cannot create or access the parent directory for ${context} at: ${parent}. Check your path or permissions.")
        }
    }
}

def sendWebhook(webhookUrl, message, status) {
    if (!webhookUrl || !webhookUrl.toString().startsWith("http")) {
        return null
    }

    def datasetName = launchDir.getName()
    def normalizedStatus = status?.toLowerCase()

    try {
        def colorBlue = 3447003
        def colorGreen = 3066993
        def colorRed = 15158332
        def colorOrange = 15105570

        def colorCode = colorBlue

        if (normalizedStatus == 'success') {
            colorCode = colorGreen
        }
        else if (normalizedStatus == 'failed' || normalizedStatus == 'error') {
            colorCode = colorRed
        }
        else if (normalizedStatus == 'warning') {
            colorCode = colorOrange
        }

        def timestamp = new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
        timestamp.setTimeZone(TimeZone.getTimeZone("UTC"))

        def descriptionText = "${message}"

        def embed = [title: datasetName, description: descriptionText, color: colorCode, timestamp: timestamp.format(new Date())]
        def payload = groovy.json.JsonOutput.toJson([embeds: [embed]])

        def connection = new URL(webhookUrl).openConnection()
        connection.setRequestMethod("POST")
        connection.setDoOutput(true)
        connection.setRequestProperty("Content-Type", "application/json")
        connection.setConnectTimeout(5000)
        connection.setReadTimeout(10000)

        // Send the payload
        def outStream = connection.getOutputStream()
        outStream.write(payload.getBytes("UTF-8"))
        outStream.flush()
        outStream.close()

        // Clear the socket buffers to prevent memory leaks on HTTP 429 Errors
        if (connection.getResponseCode() >= 400) {
            def errStream = connection.getErrorStream()
            if (errStream != null) {
                errStream.text
            }
        }
        else {
            def inStream = connection.getInputStream()
            if (inStream != null) {
                inStream.text
            }
        }

        connection.disconnect()
        return true
    }
    catch (e) {
        log.warn("Something wrong with sendWebhook: ${e.message}")
        return false
    }
}