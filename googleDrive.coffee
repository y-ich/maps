CLIENT_ID = '458982307818.apps.googleusercontent.com'
SCOPES = [
    'https://www.googleapis.com/auth/drive'
    'https://www.googleapis.com/auth/fusiontables.readonly'
]

handleClientLoad = ->
    window.setTimeout checkAuth(true), 1

checkAuth = (immediate) ->
    ->
        gapi.auth.authorize
                'client_id': CLIENT_ID
                'scope': SCOPES
                'immediate': immediate
            , handleAuthResult

handleAuthResult = (authResult) ->
    if authResult and not authResult.error
        console.log 'ok'
        gapi.client.load 'drive', 'v2', ->
            $('#button-google-drive').css 'display', 'none'
            $('#button-fusion-tables').css 'display', ''
        gapi.client.load 'fusiontables', 'v1'
    else
        console.log 'ng'
        $('#button-google-drive').text('Google Drive')
                                 .attr 'disabled', null

# for query, see https://developers.google.com/drive/search-parameters
searchFiles = (query, callback) ->
    retrievePageOfFiles = (request, result) ->
        request.execute (resp) ->
            result = result.concat resp.items
            nextPageToken = resp.nextPageToken
            if nextPageToken
                request = gapi.client.drive.files.list
                    'pageToken': nextPageToken
                retrievePageOfFiles request, result
            else
                callback result
    initialRequest = gapi.client.drive.files.list
        q: query
    retrievePageOfFiles initialRequest, []

foo = (callback) ->
    boundary = '-------314159265358979323846'
    delimiter = "\r\n--" + boundary + "\r\n"
    close_delim = "\r\n--" + boundary + "--"
    contentType = fileData.type || 'application/octet-stream'
    metadata =
        'title': fileData.name
        'mimeType': contentType

    base64Data = btoa reader.result
    multipartRequestBody =
        delimiter +
        'Content-Type: application/json\r\n\r\n' +
        JSON.stringify(metadata) +
        delimiter +
        'Content-Type: ' + contentType + '\r\n' +
        'Content-Transfer-Encoding: base64\r\n' +
        '\r\n' +
        base64Data +
        close_delim;

    request = gapi.client.request
        'path': '/upload/drive/v2/files'
        'method': 'POST'
        'params':
            'uploadType': 'multipart'
        'headers':
            'Content-Type': 'multipart/mixed; boundary="' + boundary + '"'
        'body': multipartRequestBody
    if (!callback)
        callback = (file) -> console.log(file)
    request.execute callback

window.handleClientLoad = handleClientLoad
