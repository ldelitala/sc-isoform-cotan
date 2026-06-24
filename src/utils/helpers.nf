// utils/helpers.nf
def ERR_MISS(param) {
    return "\033[0;31mPipeline error: '${param}' parameter missing.\033[0m"
}

def parseSrrIds(val) {
    if (!val) return []
    def m = (val =~ /^([A-Za-z]+)(\d+)\s*-\s*[A-Za-z]+(\d+)$/)
    if (m.matches()) {
        def prefix = m[0][1]
        def (start, end) = [m[0][2].toInteger(), m[0][3].toInteger()]
        return (start..end).collect { num -> prefix + num.toString().padLeft(m[0][2].length(), '0') }
    }
    return val.split(',').collect { srr -> srr.trim() }.findAll()
}

def sendWebhook(message) {
    sendWebhook(message, 'info')
}

def sendWebhook(message, status) {
    if (params.webhook_url) {
        def datasetName = launchDir.getName()
        def colorCode = 3447003 // Default Blue
        def emoji = "ℹ️"
        
        if (status == 'success') { colorCode = 3066993; emoji = "✅" } 
        else if (status == 'error') { colorCode = 15158332; emoji = "❌" } 
        else if (status == 'warning') { colorCode = 15105570; emoji = "⚠️" }

        def timestamp = new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
        timestamp.setTimeZone(TimeZone.getTimeZone("UTC"))
        def formattedTime = timestamp.format(new Date())

        def embed = [
            title: "${emoji} Nextflow Pipeline Notification",
            description: message,
            color: colorCode,
            timestamp: formattedTime,
            fields: [
                [name: "Dataset / Run", value: "`" + datasetName + "`", inline: true],
                [name: "Genome Assembly", value: "`" + (params.genome_assembly ?: 'N/A') + "`", inline: true],
                [name: "Step", value: "`" + params.step + "`", inline: true],
                [name: "Transcript Level", value: "`" + params.transcript_level.toString() + "`", inline: true]
            ],
            footer: [ text: "sc-isoform-pipeline" ]
        ]

        if (params.srr_ids) embed.fields.add([name: "SRA Run IDs", value: "`" + params.srr_ids + "`", inline: false])

        def payload = groovy.json.JsonOutput.toJson([embeds: [embed]])
        try {
            ['curl', '-H', 'Content-Type: application/json', '-X', 'POST', '-d', payload, params.webhook_url].execute().waitFor()
        } catch (Exception e) {
            log.warn("Webhook failed: ${e.message}")
        }
    }
}
