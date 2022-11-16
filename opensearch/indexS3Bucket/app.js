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
process.env.language = 'en'

const args = require('minimist')(process.argv.slice(2));

const indexCreationJson = { "mappings" : {"properties" : { "s3key" : { "type" : "keyword" }, "filepath" : { "type" : "text" }, "filename" : { "type" : "text" }, "bucket" : { "type" : "keyword" },"etag" : { "type" : "keyword" },"filesize" : { "type" : "long" }, "lastmodified" : { "type" : "date" }}}};

const folderMap = new Map();

var awsProfile = 'default';
var credentialsDurationSecs = 3600;

var numberFileObjectsUpdated = 0;
var numberFileObjectsUpdateFailed = 0;

const main = async () => {

  if (args['region'] != null) {
    process.env.AWS_REGION = args['region'];
  } else {
    throw '\'--region\' parameter is required!';
  }

  if (args['bucket'] != null) {
    process.env.bucket = args['bucket'];
  } else {
    throw '\'--bucket\' parameter is required!';
  }

  if (args['domain'] != null) {
    process.env.domain = args['domain'];
  } else {
    throw '\'--domain\' parameter is required!';
  }
  if (args['awsProfile'] != null) {
    process.env.AWS_PROFILE = args['awsProfile'];
    awsProfile = args['awsProfile'];
  }
  if (args['osRoleArn'] != null) {
    process.env.AWS_ROLE_ARN = args['osRoleArn'];
    //awsProfile = args['osRoleArn'];
  } else {
    throw '\'--osRoleArn\' parameter is required!';
  }
  
  var sts = new AWS.STS();
  await (async () => {
    try {
      const data = await sts.assumeRole({
        RoleArn: process.env.AWS_ROLE_ARN,
        RoleSessionName: 'IA_S3_Index',
        DurationSeconds: credentialsDurationSecs
      }).promise();
      //console.log('Assumed role success');
      //console.log(data);
      AWS.config.update({ 
        accessKeyId: data.Credentials.AccessKeyId,
        secretAccessKey: data.Credentials.SecretAccessKey,
        sessionToken: data.Credentials.SessionToken
      });
    } catch (err) {
      console.log('Cannot assume role');
      console.log(err, err.stack);
    }
   })();

  const s3Client = new AWS.S3( {credentials: AWS.config.credentials } );

  console.log("\nSyncing Bucket:" + process.env.bucket + "\n\nOpenSearch Domain Endpoint:" + process.env.domain + "\n\nRegion:" + process.env.AWS_REGION);

  //Runtime timer begin
  console.time('indexS3Bucket');

  // Prefixes are used to fetch data in parallel.
  const numbers = '0123456789'.split('');
  const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
  const special = "!-_'*()".split(''); // "Safe" S3 special chars (removed . to exclude hidden directory and files)
  const prefixes = [...numbers, ...letters, ...special];

  // array of params used to call listObjectsV2 in parallel for each prefix above
  const arrayOfParams = prefixes.map((prefix) => {
    return { Bucket: process.env.bucket, Prefix: prefix }
  });

  // delete bucket index if exists
  try {
    await openSearchClient('DELETE', process.env.bucket, '');
  } catch (error) {
    console.log("DELETE bucket index ERROR: " +error)
  }

  // Take a breath after a deleting the index
  await new Promise(r => setTimeout(r, 5000));

  //create new bucket index
  try {
    await openSearchClient('PUT', process.env.bucket, JSON.stringify(indexCreationJson));
  } catch (error) {
    console.log("DELETE bucket index ERROR: " +error)
  }

  await new Promise(r => setTimeout(r, 1000));

  try {
      await Promise.all(arrayOfParams.map(params => getAllKeys(params, s3Client)));
  } catch (error) {
      console.log("Promise was rejected within getAllKeys method: "+error);
  }
  

  console.timeEnd('indexS3Bucket')

  return 0;
};

/*
Here's the problem: you are assuming there should always be objects with keys ending in / to symbolize folders with S3.

This is an incorrect assumption. They will only be there if you created them, either via the S3 console or the API. There's no reason to expect them, as S3 doesn't actually need them or use them for anything, and the S3 service does not create them spontaneously, itself.

If you use the API to upload an object with key foo/bar.txt, this does not create the foo/ folder as a distinct object. It will appear as a folder in the console for convenience, but it isn't there unless at some point you deliberately created it.

Of course, the only way to upload such an object with the console is to "create" the folder unless it already appears -- but appears in the console does not necessarily equate to exists as a distinct object.
*/

async function getAllKeys(params, s3Client) {

  var fileObjects = [];
  const response = await s3Client.listObjectsV2(params).promise();
  response.Contents.forEach(async function(obj) {
    if (!obj.Key.endsWith('/')) {
      var folderName = obj.Key.substring(0,obj.Key.lastIndexOf("/")+1);
      fileObjects.push(
        {
          s3key: obj.Key,
          filepath: obj.Key,
          filename: obj.Key.replace(/^.*[\\\/]/, ''),
          bucket: process.env.bucket,
          etag: obj.ETag,
          filesize: obj.Size,
          lastmodified: obj.LastModified
        }
      );
      

      // Read comment above method.  We have to create fileobjects that represent folders as there is an inconsistency in folder creation and representation.
      // A map is maintained with a global state of created folders.  If already created, it won't be created again.
      var pathComponents = folderName.split('/');
      if (pathComponents.length > 1) {
        var syntheticPath = "";
        pathComponents.forEach(async function(pathComponent) {
          if (pathComponent != "") {
            syntheticPath += pathComponent + "/";
            if (!folderMap.has(syntheticPath)) {
              folderMap.set(syntheticPath, true);
              fileObjects.push(
                {
                  s3key: syntheticPath,
                  filepath: syntheticPath,
                  filename: '',
                  bucket: process.env.bucket,
                  etag: '',
                  filesize: 0,
                  lastmodified: Date.now()
                }
              );
            }
          }
        });
      } 
    }
  });


  var bulkUpdateResponse = indexBucketMetadata(fileObjects, process.env.bucket);

  if (bulkUpdateResponse) {
    numberFileObjectsUpdated += fileObjects.length;
  } else {
    numberFileObjectsUpdateFailed += fileObjects.length;
  }

  console.log("Total File Objects Updated:" + numberFileObjectsUpdated + " Failed:"  + numberFileObjectsUpdateFailed);
  console.timeLog("indexS3Bucket");

  if (response.NextContinuationToken) {
    params.ContinuationToken = response.NextContinuationToken;
    await getAllKeys(params, s3Client); // RECURSIVE CALL
  }
}

// Load file data, save to OpenSearch Domain Instance
const indexBucketMetadata = async (payload) => {

  if (payload.length > 0) {
    var bulkRequestBody = '';
    payload.forEach(async function(obj) {
      bulkRequestBody += '{"index":{"_index":"' + process.env.bucket + '"}}\n';
      bulkRequestBody += JSON.stringify(obj) + '\n';
    });
    return await openSearchClient('PUT', '_bulk', bulkRequestBody, payload.length);
  }
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
        if (response.statusCode != 200) {
          console.log('Response body: ' + responseBody);
          reject(false);
        }
        resolve(true)
      });
    }, function(error) {
      console.log('Error: ' + error)
      reject(false)
    })
  })
}

main().catch(error => console.error(error))
