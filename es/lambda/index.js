/**************************
 * This program is protected under international and U.S. copyright laws as
 * an unpublished work. This program is confidential and proprietary to the
 * copyright owners. Reproduction or disclosure, in whole or in part, or the
 * production of derivative works therefrom without the express permission of
 * the copyright owners is prohibited.
 *
 * Copyright (C) 2021 GrayMeta, Inc. All rights reserved.
 * Original Author: Scott Sharp
 *
 **************************/

 'use strict'

 const AWS = require('aws-sdk');
 
 AWS.config.region = process.env.region 
 
 // The Lambda handler
 exports.handler = (event) => {
 
   // Handle each incoming S3 object in the event
   Promise.all(
     event.Records.map((event) => {
       
       try {
         if (event.eventName.startsWith('ObjectCreated:')) {
           processCreateEvent(event)
         } else if (event.eventName.startsWith('ObjectRemoved:')) {
           processDeleteEvent(event)
         }
       } catch (err) {
         console.error(`Handler error: ${err}`)
       }
     })
   )
 }
 
 // Add S3 Object to bucket index
 const processCreateEvent = (event) => {
   
  const search = '\\+';
  const searchRegExp = new RegExp(search, 'g');

   // Payload object for ES index insertion
   var response = openSearchClient('POST', event.s3.bucket.name + '/_doc', JSON.stringify({
     s3key : event.s3.object.key,
     filepath: event.s3.object.key.replace(searchRegExp, ' '),
     filename: event.s3.object.key.replace(/^.*[\\\/]/, '').replace(searchRegExp, ' '),
     bucket: event.s3.bucket.name,
     etag: event.s3.object.eTag,
     filesize: event.s3.object.Size,
     lastmodified : Date.now()
   }));
   console.log("Inserted index item for event!\n\n" + JSON.stringify(event));
 }
 
 // Delete S3 Object from bucket index
 const processDeleteEvent = (event) => {
   
   var requestBody = {"query": {"term": {"s3key": event.s3.object.key}}}
   openSearchClient('GET', event.s3.bucket.name + '/_search', JSON.stringify(requestBody)).then((searchResponse) => {
     var deletedEntry = false;
     //console.log(JSON.stringify(searchResponse));
     searchResponse.hits.hits.map((searchHit) => {
 
         // Objects in S3 are globally unique when inclueding the bucket with the path
         if (searchHit._source.bucket.trim() == event.s3.bucket.name.trim()) {
           if (searchHit._source.s3key.trim() == event.s3.object.key.trim()) {
             //console.log(JSON.stringify(searchHit));
             deletedEntry = true;
             var response = openSearchClient('DELETE', event.s3.bucket.name + '/_doc/' + searchHit._id, '');
             console.log("Deleted index item for event!\n\n" + JSON.stringify(event));
           }
         }
     });
     if (!deletedEntry) {
       console.log("Didn't delete index item for event!\n\n" + JSON.stringify(event));
     }
   });
 }
 
 const openSearchClient = (httpMethod, path, requestBody) => {
   return new Promise((resolve, reject) => {
     const endpoint = new AWS.Endpoint(process.env.domain)
     let request = new AWS.HttpRequest(endpoint, process.env.AWS_REGION)
 
     //console.log(requestBody);
 
     request.method = httpMethod;
     request.path += path;
     request.body = requestBody;
     request.headers['host'] = endpoint.host;
     request.headers['Content-Type'] = 'application/json';
     request.headers['Content-Length'] = Buffer.byteLength(request.body)
 
     const credentials = { accessKeyId: process.env.domain_key_id, secretAccessKey: process.env.domain_secret_key, region: process.env.region }
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
         //console.log(responseBody);
         resolve(JSON.parse(responseBody));
       });
     }, function(error) {
       console.log('Error: ' + error)
       reject()
     })
   })
 }