
'use strict'

const AWS = require('aws-sdk');
AWS.config.region = process.env.AWS_REGION;
const s3 = new AWS.S3();

const args = require('minimist')(process.argv.slice(2));


process.env.language = 'en'
//process.env.domain = 'search-index-s3-iris-aws-dev-mcqnhh3vm2226xpi53neo4pzwu.us-west-2.es.amazonaws.com'

const indexCreationJson = { "settings" : {"number_of_shards" : 2,"number_of_replicas" : 1},"mappings" : {"properties" : {"path" : { "type" : "text" },"name" : { "type" : "text" },"bucket" : { "type" : "text" },"etag" : { "type" : "text" },"fileSize" : { "type" : "long" }, "lastModified" : { "type" : "date" }}}};

var numberFileObjectsUpdated = 0;

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
    deleteBucketIndex();
  } catch (error) {}

  //create new bucket index
  createBucketIndex();

  await Promise.all(arrayOfParams.map(params => getAllKeys(params)));
  console.timeEnd('indexS3Bucket')
};

async function getAllKeys(params){
  var fileObjects = [];

  const response = await s3.listObjectsV2(params).promise();
  response.Contents.forEach(async function(obj) {
    if ((obj.Size > 0) || (args['indexFolders'] != null)) {
      fileObjects.push(
        {
          path: obj.Key,
          name: obj.Key.replace(/^.*[\\\/]/, ''),
          bucket: process.env.bucket,
          etag: obj.ETag,
          fileSize: obj.Size,
          lastModified : obj.lastModified
        }
      );
    }
  });


  indexBucketMetadata(fileObjects, process.env.bucket);

  numberFileObjectsUpdated += fileObjects.length;

  console.log("Total File Objects Updated:" + numberFileObjectsUpdated);
  console.timeLog("indexS3Bucket");

  if (response.NextContinuationToken) {
    params.ContinuationToken = response.NextContinuationToken;
    await getAllKeys(params); // RECURSIVE CALL
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
    await openSearchClient('PUT', '_bulk', bulkRequestBody);
  }
}

const createBucketIndex = async (payload) => {
  await openSearchClient('PUT', process.env.bucket, JSON.stringify(indexCreationJson));
}

const deleteBucketIndex = async (payload) => {
  await openSearchClient('DELETE', process.env.bucket, '');
}

const openSearchClient = async (httpMethod, path, requestBody) => {
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

main().catch(error => console.error(error))
