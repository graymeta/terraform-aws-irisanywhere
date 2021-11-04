
'use strict'

const AWS = require('aws-sdk');

AWS.config.region = process.env.AWS_REGION 
const s3 = new AWS.S3()

// The Lambda handler
exports.handler = async (event) => {

  // Handle each incoming S3 object in the event
  await Promise.all(
    event.Records.map(async (event) => {
      //console.log(event);
      console.log(event.eventName);
      try {
        if (event.eventName.startsWith('ObjectCreated:')) {
          await processCreateEvent(event)
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
  
  console.log('\n\nCreated\n\n');
  
  /*const Key = decodeURIComponent(event.Key.replace(/\+/g, ' '))
  const Bucket = event.Bucket
  const type = Key.split('/')[0]
  console.log(`Bucket: ${Bucket}, Key: ${Key}, Type: ${type}`)*/

  // Payload object for ES
  /*let payload = {
    path: obj.Key,
    name: obj.Key.replace(/^.*[\\\/]/, ''),
    bucket: process.env.bucket,
    etag: obj.ETag,
    fileSize: obj.Size,
    lastModified : obj.lastModified
  }*/

  // This is the payload for Elasticsearch
  //console.log('Payload: ', JSON.stringify(payload, null, 2))
  //await indexDocument(payload)
}

// Delete S3 Object from bucket index
const processDeleteEvent = async (event) => {
  
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
