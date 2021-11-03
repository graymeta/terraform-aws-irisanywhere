
const AWS = require('aws-sdk')
AWS.config.region = process.env.AWS_REGION
const type = '_doc'

const indexDocument = async (event) => {
  return new Promise((resolve, reject) => {
    const endpoint = new AWS.Endpoint(process.env.domain)
    let request = new AWS.HttpRequest(endpoint, process.env.AWS_REGION)
    const document = event.content

    request.method = 'PUT'
    request.path += event.index + '/' + type + '/' + event.id
    request.body = JSON.stringify(document)
    request.headers['host'] = endpoint.host
    request.headers['Content-Type'] = 'application/json';
    request.headers['Content-Length'] = Buffer.byteLength(request.body)

    const credentials = new AWS.EnvironmentCredentials('AWS')
    const signer = new AWS.Signers.V4(request, 'es')
    signer.addAuthorization(credentials, new Date())

    const client = new AWS.HttpClient()
    client.handleRequest(request, null, function(response) {
      console.log(response.statusCode + ' ' + response.statusMessage)
      let responseBody = ''
      response.on('data', function (chunk) {
        responseBody += chunk;
      });
      response.on('end', function (chunk) {
        console.log('Response body: ' + responseBody)
        resolve()
      });
    }, function(error) {
      console.log('Error: ' + error)
      reject()
    })
  })
}

module.exports = { indexDocument }
