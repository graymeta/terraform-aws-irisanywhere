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
 
 AWS.config.region = process.env.AWS_REGION; 
 
 // The Lambda handler
 exports.handler = (event) => {
   // Handle each incoming S3 object in the event
   Promise.all(
     event.Records.map((event) => {
       try {
        if(isPresent(event.Sns)) {
          let snsMsg = formatMsg(event.Sns.Message)
          event = JSON.parse(snsMsg).Records[0]
        }
         if (event.eventName.startsWith('ObjectCreated:')) {
           processCreateEvents(event)
         } else if (event.eventName.startsWith('ObjectRemoved:')) {
           processDeleteEvent(event)
         }
       } catch (err) {
         console.error(`Handler error: ${err}`)
       }
     })
   )
 }
 
 //Note this plural function is different than the singular function
 function processCreateEvents(event) {
  var s3EventKey = escapeS3Key(event.s3.object.key);
  
  if(isPresent(s3EventKey)) {
   //Start by inserting full key path
   processCreateEvent(event);
   //Determine folder count in key.
   var keysToIndex = s3EventKey.toString().split("/")
   var keysLen = keysToIndex.length;

   //initial key substring which is entire key path
   var keySubString = s3EventKey;
   
   for(var i=0; i<(keysLen-1); i++) {
    var keySubStringIndex = keySubString.lastIndexOf("/");
    keySubString = s3EventKey.substring(0,keySubStringIndex);
    event.s3.object.key = keySubString.concat("/");
    //create the event with the new key
    processCreateEvent(event);
   }
  }
 }
 
 function isPresent(o) {
   return (o != undefined && o != null) ? true : false;
 }
 
 function formatMsg(unformattedJSONString) {
  return unformattedJSONString.replace(/\\/g,"");
 }
 
 
 // Add S3 Object to bucket index
 function processCreateEvent(event) {
  var s3EventKey = escapeS3Key(event.s3.object.key);
  
   // Payload object for ES index insertion, ignore any hidden folders or files (begins with .)
   if (!s3EventKey.startsWith(".")) {
    //Does object already exist in the index

     var requestBody = { "query": { "term": { "s3key": s3EventKey } } };
     openSearchClient('GET', event.s3.bucket.name + '/_search', JSON.stringify(requestBody)).then((searchResponse) => {
      let objExists = (parseInt(searchResponse.hits.total.value, 10) > 0)  ?  true :  false;
      if(!objExists) {
       var response = openSearchClient('POST', event.s3.bucket.name + '/_doc', JSON.stringify({
         s3key: s3EventKey,
         filepath: s3EventKey,
         filename: s3EventKey.replace(/^.*[\\\/]/, ''),
         bucket: event.s3.bucket.name,
         etag: event.s3.object.eTag,
         filesize: event.s3.object.Size,
         lastmodified: Date.now()
       })).then((insertResponse) => {
         if ('created' == insertResponse.result) {
           console.log("Inserted index item for event!\n\n" + JSON.stringify(event));
         } else {
           console.log("Failed to insert index item for event!\n\n" + JSON.stringify(event));
         }
       });
       
    } else {
       //if objExists
       searchResponse.hits.hits.map((searchHit) => {
         var updateRequestBody = JSON.stringify({doc: {lastmodified: Date.now()}});
         var response = openSearchClient('POST', event.s3.bucket.name + '/_update/' + searchHit._id, updateRequestBody)
         .then((updateResponse) =>
         {
          if('updated' == updateResponse.result) {
            console.log("Updated object ID: " + JSON.stringify(event));
          } else {
            console.log("Failed to update object ID: " +JSON.stringify(event));
          }
         });
       });
     }      
   });
  }
 }
 
 
 // Delete S3 Object from bucket index, ignore any hidden folders or files (begins with .)
 function processDeleteEvent(event)  {
   var s3EventKey = escapeS3Key(event.s3.object.key);
   if (!s3EventKey.startsWith(".")) {
     var requestBody = { "query": { "term": { "s3key": s3EventKey } } }
     openSearchClient('GET', event.s3.bucket.name + '/_search', JSON.stringify(requestBody)).then((searchResponse) => {
       var deletedEntry = false;
       //console.log(JSON.stringify(searchResponse));
       searchResponse.hits.hits.map((searchHit) => {

         // Objects in S3 are globally unique when inclueding the bucket with the path
         if (searchHit._source.bucket.trim() == event.s3.bucket.name.trim()) {
           if (searchHit._source.s3key.trim() == s3EventKey.trim()) {
             //console.log(JSON.stringify(searchHit));
             deletedEntry = true;
             var response = openSearchClient('DELETE', event.s3.bucket.name + '/_doc/' + searchHit._id, '');
             console.log("Deleted index item for event!\n\n" + JSON.stringify(event));
           }
         }
       });
       if (!deletedEntry) {
         console.log("Failed to delete index item for event!\n\n" + JSON.stringify(event));
       }
     });
   }
 }
 
 // Escape and non-standard filesystem naming characters per 'https://www.w3schools.com/tags/ref_urlencode.ASP'
 function escapeS3Key(s3Key) {
  const searchPlus = '\\+';
  const searchRegExp = new RegExp(searchPlus, 'g');

  return decodeURIComponent(s3Key.replace(searchRegExp, '%20'));
 }

 // Generic OpenSearch client
 function openSearchClient(httpMethod, path, requestBody) {
   return new Promise((resolve, reject) => {
     const endpoint = new AWS.Endpoint(process.env.domain)
     let request = new AWS.HttpRequest(endpoint, process.env.AWS_REGION);
 
     request.method = httpMethod;
     request.path += path;
     request.body = requestBody;
     request.headers['host'] = endpoint.host;
     request.headers['Content-Type'] = 'application/json';
     request.headers['Content-Length'] = Buffer.byteLength(request.body)
     
     const credentials = { accessKeyId: AWS.config.credentials.accessKeyId, secretAccessKey: AWS.config.credentials.secretAccessKey, sessionToken: AWS.config.credentials.sessionToken };
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
         console.log("ResponseBody:" + responseBody);
         resolve(JSON.parse(responseBody));
       });
     }, function(error) {
       console.log('Error: ' + error)
       reject()
     })
   })
 }