/**************************
 * This program is protected under international and U.S. copyright laws as
 * an unpublished work. This program is confidential and proprietary to the
 * copyright owners. Reproduction or disclosure, in whole or in part, or the
 * production of derivative works therefrom without the express permission of
 * the copyright owners is prohibited.
 *
 * Copyright (C) 2021 GrayMeta, Inc. All rights reserved.
 * Author: Graymeta Development Team
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
var credentialsDurationSecs = 10800;

var numberFileObjectsIndexed = 0;
var numberFileObjectsIndexFailed = 0;
var indexFailureMessages = [];

const main = async () => {

  if (args['region'] != null) {
    process.env.AWS_REGION = args['region'];
    AWS.config.update({ region: args['region'] });
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
      throw new Error(`Could not assume the AWS role: ${err.message || err}`);
    }
   })();

  let s3Client = new AWS.S3({ credentials: AWS.config.credentials, region: process.env.AWS_REGION });

  console.log("\nSyncing Bucket:" + process.env.bucket + "\n\nOpenSearch Domain Endpoint:" + process.env.domain + "\n\nRegion:" + process.env.AWS_REGION);

  //Runtime timer begin
  console.time('indexS3Bucket');

  let bucketRegion = process.env.AWS_REGION;
  let bucketValidated = false;
  try {
    const bucketResponse = await s3Client.headBucket({ Bucket: process.env.bucket }).promise();
    bucketValidated = true;
    bucketRegion = getS3BucketRegion(bucketResponse) || bucketRegion;
  } catch (error) {
    bucketRegion = getS3BucketRegion(error);
    if (!bucketRegion) {
      throw new Error(formatS3Error(error));
    }
  }

  if (bucketRegion !== process.env.AWS_REGION) {
    console.log(`S3 bucket region: ${bucketRegion}; OpenSearch region: ${process.env.AWS_REGION}`);
    s3Client = new AWS.S3({ credentials: AWS.config.credentials, region: bucketRegion });
  }
  if (!bucketValidated) {
    try {
      await s3Client.headBucket({ Bucket: process.env.bucket }).promise();
    } catch (error) {
      throw new Error(formatS3Error(error));
    }
  }

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
  let indexDeleted;
  try {
    indexDeleted = await openSearchClient('DELETE', process.env.bucket, '', { notFoundIsExpected: true });
  } catch (error) {
    throw new Error(formatOpenSearchError('connect to', error));
  }
  if (!indexDeleted) {
    console.log(`Index ${process.env.bucket} does not yet exist, we will create it now`);
  }

  // Take a breath after a deleting the index
  await new Promise(r => setTimeout(r, 5000));

  //create new bucket index
  try {
    await openSearchClient('PUT', process.env.bucket, JSON.stringify(indexCreationJson));
  } catch (error) {
    throw new Error(formatOpenSearchError('create the index in', error));
  }

  await new Promise(r => setTimeout(r, 1000));

  const progressInterval = setInterval(() => {
    const progress = `File Objects Indexed: ${numberFileObjectsIndexed}`;
    console.log(numberFileObjectsIndexFailed > 0
      ? `${progress} Failed: ${numberFileObjectsIndexFailed}`
      : progress);
  }, 5000);

  const scanResults = await Promise.allSettled(
    arrayOfParams.map(params => getAllKeys(params, s3Client))
  );
  clearInterval(progressInterval);
  const failedScans = scanResults.filter(result => result.status === 'rejected');

  scanResults.forEach((result, index) => {
    if (result.status === 'rejected') {
      console.error(`Failed to scan S3 prefix ${prefixes[index]}: ${formatS3Error(result.reason)}`);
    }
  });

  if (indexFailureMessages.length > 0) {
    console.error(indexFailureMessages.join('\n'));
  }
  if (failedScans.length > 0) {
    console.error(`Failed S3 prefix scans: ${failedScans.length}`);
  }

  const indexSummary = `Total File Objects Indexed: ${numberFileObjectsIndexed}`;
  console.log(numberFileObjectsIndexFailed > 0
    ? `${indexSummary} Failed: ${numberFileObjectsIndexFailed}`
    : indexSummary);

  console.timeEnd('indexS3Bucket')

  return failedScans.length > 0 ? 1 : 0;
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
  (response.Contents || []).forEach(function(obj) {
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
        pathComponents.forEach(function(pathComponent) {
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


  if (fileObjects.length > 0) {
    let indexResult;
    try {
      indexResult = await indexBucketMetadata(fileObjects);
    } catch (error) {
      numberFileObjectsIndexFailed += fileObjects.length;
      const objectKeys = fileObjects.map(obj => JSON.stringify(obj.s3key)).join(', ');
      indexFailureMessages.push(`Could not confirm indexing for ${fileObjects.length} file objects (${objectKeys}): ${error.message || error}`);
      indexResult = null;
    }

    if (indexResult) {
      numberFileObjectsIndexed += indexResult.indexed;
      numberFileObjectsIndexFailed += indexResult.failures.length;
      indexFailureMessages.push(...indexResult.failures);
    }
  }

  if (response.NextContinuationToken) {
    params.ContinuationToken = response.NextContinuationToken;
    await getAllKeys(params, s3Client); // RECURSIVE CALL
  }
}

// Load file data, save to OpenSearch Domain Instance
const indexBucketMetadata = async (payload) => {
  if (payload.length > 0) {
    var bulkRequestBody = '';
    payload.forEach(function(obj) {
      bulkRequestBody += '{"index":{"_index":"' + process.env.bucket + '"}}\n';
      bulkRequestBody += JSON.stringify(obj) + '\n';
    });

    const bulkResponse = await openSearchClient('PUT', '_bulk', bulkRequestBody, { parseJsonResponse: true });
    if (!Array.isArray(bulkResponse.items) || bulkResponse.items.length !== payload.length) {
      throw new Error(`Expected ${payload.length} bulk item results`);
    }

    const failures = [];
    bulkResponse.items.forEach((item, index) => {
      const result = item && item.index;
      if (!result || result.error || !Number.isInteger(result.status) || result.status < 200 || result.status >= 300) {
        const status = result && Number.isInteger(result.status) ? `HTTP ${result.status}` : 'status unavailable';
        const details = result && result.error ? JSON.stringify(result.error) : 'No successful item result returned';
        failures.push(`Failed to index S3 object ${JSON.stringify(payload[index].s3key)} (${status}): ${details}`);
      }
    });

    return { indexed: payload.length - failures.length, failures };
  }
};

const openSearchClient = async (httpMethod, path, requestBody, options = {}) => {
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
        if (response.statusCode === 404 && options.notFoundIsExpected) {
          resolve(false);
          return;
        }
        if (response.statusCode != 200) {
          const error = new Error(`OpenSearch request failed with HTTP ${response.statusCode}: ${responseBody}`);
          reject(error);
          return;
        }
        if (options.parseJsonResponse) {
          try {
            resolve(JSON.parse(responseBody));
          } catch (error) {
            reject(new Error(`Invalid OpenSearch bulk response: ${error.message}`));
          }
          return;
        }
        resolve(true)
      });
    }, function(error) {
      reject(error);
    })
  })
}

function formatS3Error(error) {
  const errorCode = error && (error.code || error.name);
  if (errorCode === 'NoSuchBucket' || errorCode === 'InvalidBucketName' || errorCode === 'NotFound' || (error && error.statusCode === 404)) {
    return `S3 bucket "${process.env.bucket}" was not found or is inaccessible. Check the bucket name and AWS permissions.`;
  }
  if (errorCode === 'PermanentRedirect' || (error && error.statusCode === 301)) {
    return `Could not reach S3 bucket "${process.env.bucket}" in its reported region. Check the bucket name, AWS permissions, and network access.`;
  }
  if (errorCode === 'AccessDenied' || errorCode === 'Forbidden' || (error && error.statusCode === 403)) {
    return `Access denied while reading S3 bucket "${process.env.bucket}". Check the AWS role permissions.`;
  }
  return `S3 request failed: ${(error && error.message) || error}`;
}

function getS3BucketRegion(response) {
  if (response && response.region) {
    return response.region;
  }
  const headers = response && response.$response && response.$response.httpResponse && response.$response.httpResponse.headers;
  return headers && (headers['x-amz-bucket-region'] || headers['X-Amz-Bucket-Region']);
}

function formatOpenSearchError(action, error) {
  const details = (error && error.message) || String(error);
  if ((error && (error.code === 'ENOTFOUND' || error.code === 'EAI_AGAIN')) || /getaddrinfo ENOTFOUND|EAI_AGAIN/i.test(details)) {
    return `Could not resolve the OpenSearch domain "${process.env.domain}". Check the --domain value and DNS/network access.`;
  }
  return `Could not ${action} OpenSearch domain "${process.env.domain}": ${details}`;
}

main().then(exitCode => {
  if (exitCode !== 0) {
    process.exitCode = exitCode;
  }
}).catch(error => {
  console.error(error.message || error);
  process.exitCode = 1;
})
