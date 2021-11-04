
'use strict'

const AWS = require('aws-sdk');

var opensearch = new AWS.OpenSearch({ endpoint : process.env.domain });

AWS.config.region = process.env.AWS_REGION 

// The Lambda handler
exports.handler = async (event) => {

  // Handle each incoming S3 object in the event
  await Promise.all(
    event.Records.map(async (event) => {
      //console.log(event);
      console.log(event);
      try {
        if (event.eventName.startsWith('ObjectCreated:')) {
          //await processCreateEvent(event)
        } else if (event.eventName.startsWith('ObjectRemoved:')) {
          await processDeleteEvent(event)
        }
      } catch (err) {
        console.error(`Handler error: ${err}`)
      }
    })
  )
}

// Add S3 Object to bucket index
const processCreateEvent = async (event) => {
  
  // Payload object for ES index insertion
  await openSearchClient('POST', event.s3.bucket.name + '/_doc', JSON.stringify({
    path: event.s3.object.key,
    name: event.s3.object.key.replace(/^.*[\\\/]/, ''),
    bucket: event.s3.bucket.name,
    etag: event.s3.object.eTag,
    fileSize: event.s3.object.Size,
    lastModified : Date.now()
  }), 1);
}

// Delete S3 Object from bucket index
const processDeleteEvent = async (event) => {
  console.log('\n\nDeleted\n\n');
}

const openSearchClient = async (httpMethod, path, requestBody, fileObjectCount) => {
  return new Promise((resolve, reject) => {
    const endpoint = new AWS.Endpoint(process.env.domain)
    let request = new AWS.HttpRequest(endpoint, process.env.AWS_REGION)

    request.method = httpMethod;
    request.path += path;
    request.body = requestBody;
    request.headers['host'] = endpoint.host;
    request.headers['Content-Type'] = 'application/json';
    request.headers['Content-Length'] = Buffer.byteLength(request.body)

    const credentials = new AWS.SharedIniFileCredentials('default')
    const signer = new AWS.Signers.V4(request, 'es')
    signer.addAuthorization(credentials, new Date())

    const client = new AWS.HttpClient()
    client.handleRequest(request, null, function(response) {
      //console.log(response.statusCode + ' ' + response.statusMessage)
      let responseBody = ''
      response.on('data', function (chunk) {
        responseBody += chunk;
      });
      response.on('end', function (chunk) {
        if (response.statusCode != 200) {
          console.log('Response body: ' + responseBody);
        }
        resolve()
      });
    }, function(error) {
      console.log('Error: ' + error)
      reject()
    })
  })
}
