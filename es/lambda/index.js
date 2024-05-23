/**************************
 * This program is protected under international and U.S. copyright laws as
 * an unpublished work. This program is confidential and proprietary to the
 * copyright owners. Reproduction or disclosure, in whole or in part, or the
 * production of derivative works therefrom without the express permission of
 * the copyright owners is prohibited.
 *
 * Copyright (C) 2021 GrayMeta, Inc. All rights reserved.
 * Original Author: Graymeta DevOps
 *
 **************************/
"use strict";

const AWS = require("aws-sdk");
const OBJ_CREATE = "ObjectCreated:";
const OBJ_DELETE = "ObjectRemoved:";

AWS.config.region = process.env.AWS_REGION;

// The Lambda handler
exports.handler = async (event) => {
  // Handle each incoming S3 object in the event
  for (let ev of event.Records) {
    try {
      if (isPresent(ev.Sns)) {
        let snsMsg = formatMsg(ev.Sns.Message);
        let records = JSON.parse(snsMsg).Records;
        for (let record of records) {
          /* Determine event type & process accordingly */
          if (record.eventName.startsWith(OBJ_CREATE)) {
            await processCreateEvents(record);
          } else if (record.eventName.startsWith(OBJ_DELETE)) {
            await processDeleteEvent(record);
          }
        }
      } else {
        if (ev.eventName.startsWith(OBJ_CREATE)) {
          await processCreateEvents(ev);
        } else if (ev.eventName.startsWith(OBJ_DELETE)) {
          await processDeleteEvent(ev);
        }
      }
    } catch (err) {
      console.error("GM_ERROR_HANDLER: " + err + " " + JSON.stringify(event));
    }
  }
};

//Note this plural function is different than the singular function
async function processCreateEvents(event) {
  var prefixArray = [];
  var s3EventKey = escapeS3Key(event.s3.object.key);
  if (isPresent(s3EventKey)) {
    var keysToIndex = s3EventKey.toString().split("/");
    var keysLen = keysToIndex.length;
    //If event ONLY contains folders
    var isFolder =
      s3EventKey.length - 1 == s3EventKey.lastIndexOf("/") ? true : false;

    //This processes initial event with full key path
    //ONLY INSERT FULL KEY if it contains a file.  AVOID folder events here.
    try {
      if (!isFolder) {
        await processCreateEvent(event).catch((error) => {
          console.error(
            "GM_ERROR_PROCESSCREATEEVENTS_CAUGHT_PROMISE_ON_FILE: " +
              error +
              ": " +
              s3EventKey
          );
          return;
        });
      }
      //Determine folder count in key.
      //initial key substring which is entire key path
      var keySubString = s3EventKey;
      //LOOP creates new event keys for each folder in key path
      for (var i = 0; i < keysLen - 1; i++) {
        var keySubStringIndex = keySubString.lastIndexOf("/");
        keySubString = s3EventKey.substring(0, keySubStringIndex);
        event.s3.object.key = keySubString.concat("/");
        event.s3.object.size = 0;
        if (!prefixArray.includes(event.s3.object.key)) {
          prefixArray.push(event.s3.object.key);
          await processCreateEvent(event).catch((error) => {
            console.error(
              "GM_ERROR_CAUGHT_PROMISE_FOLDER_CREATION: " +
                error +
                ": " +
                event.s3.object.key
            );
            return;
          });
        }
      }
    } catch (error) {
      throw new Error(
        "GM_ERROR_PROCESSCREATEEVENTS_GENERIC: " + error + ": " + s3EventKey
      );
    }
  }
}

// Add S3 Object to bucket index
function processCreateEvent(event) {
  return new Promise((resolve, reject) => {
    var s3EventKey = escapeS3Key(event.s3.object.key);
    // Ignore any hidden folders or files (begins with .)
    if (!s3EventKey.startsWith(".")) {
      let keyExists = false;
      var requestBody = { query: { term: { s3key: s3EventKey } } };
      openSearchClient(
        "GET",
        event.s3.bucket.name + "/_search",
        JSON.stringify(requestBody)
      )
        .then((searchResponse) => {
          try {
            keyExists =
              parseInt(searchResponse.hits.total.value, 10) > 0 ? true : false;
          } catch (err) {
            return reject(
              new Error(
                "GM_ERROR_PROCESSCREATEEVENT_SEARCH_RESPONSE: " +
                  err +
                  ": " +
                  s3EventKey
              )
            );
          }
          // If this _doc DOES NOT exist, create it
          if (!keyExists) {
            openSearchClient(
              "POST",
              event.s3.bucket.name + "/_doc",
              JSON.stringify({
                s3key: s3EventKey,
                filepath: s3EventKey,
                filename: s3EventKey.replace(/^.*[\\\/]/, ""),
                bucket: event.s3.bucket.name,
                etag: event.s3.object.eTag,
                filesize: event.s3.object.size,
                lastmodified: Date.now(),
              })
            )
              .then((insertResponse) => {
                if ("created" == insertResponse.result) {
                  logResult(insertResponse, s3EventKey);
                  resolve(insertResponse);
                } else {
                  reject(insertResponse);
                }
              })
              .catch((error) => {
                console.error(error + ": " + s3EventKey);
                return;
              });
          } else {
            // If this _doc DOES exist, update it


            for (let searchHit of searchResponse.hits.hits) {
              var updateRequestBody = JSON.stringify({
                doc: { lastmodified: Date.now() },
              });
              openSearchClient(
                "POST",
                event.s3.bucket.name + "/_update/" + searchHit._id,
                updateRequestBody
              )
                .then((updateResponse) => {
                  if ("updated" == updateResponse.result) {
                    logResult(updateResponse, s3EventKey);
                    resolve(updateResponse);
                  } else {
                    reject(updateResponse);
                  }
                })
                .catch((error) => {
                  console.error(error + ": " + s3EventKey);
                  return;
                });
            }


          }
        })
        .catch((error) => {
          console.error(error + ": " + s3EventKey);
          return;
        });
    }
  });
}

// Delete S3 Object from bucket index, ignore any hidden folders or files (begins with .)
function processDeleteEvent(event) {
  return new Promise((resolve, reject) => {
    try {
      var s3EventKey = escapeS3Key(event.s3.object.key);
      if (!s3EventKey.startsWith(".")) {
        var requestBody = { query: { term: { s3key: s3EventKey } } };
        openSearchClient(
          "GET",
          event.s3.bucket.name + "/_search",
          JSON.stringify(requestBody)
        )
          .then((searchResponse) => {
            searchResponse.hits.hits.map((searchHit) => {
              // Objects in S3 are globally unique when inclueding the bucket with the path
              if (
                searchHit._source.bucket.trim() == event.s3.bucket.name.trim()
              ) {
                if (searchHit._source.s3key.trim() == s3EventKey.trim()) {
                  openSearchClient(
                    "DELETE",
                    event.s3.bucket.name + "/_doc/" + searchHit._id,
                    ""
                  )
                    .then((deleteResponse) => {
                      if ("deleted" == deleteResponse.result) {
                        console.log("GM_SUCCESS_DELETED_ITEM: ", s3EventKey);
                        resolve(deleteResponse);
                      } else {
                        console.error("GM_ERROR_DELETE: ", s3EventKey);
                        reject(deleteResponse);
                      }
                    })
                    .catch((error) => {
                      console.error(error + ": " + s3EventKey);
                      return;
                    });
                }
              }
            });
          })
          .catch((error) => {
            console.error(error + ": " + s3EventKey);
            return;
          });
      }
    } catch (error) {
      console.error(
        "GM_ERROR_PROCESSDELETEEVENT: " +
          error.toString() +
          ": for key: " +
          s3EventKey
      );
    }
  });
}

// Generic OpenSearch client
function openSearchClient(httpMethod, path, requestBody) {
  return new Promise((resolve, reject) => {
    const endpoint = new AWS.Endpoint(process.env.domain);
    let request = new AWS.HttpRequest(endpoint, process.env.AWS_REGION);

    request.method = httpMethod;
    request.path += path;
    request.body = requestBody;
    request.headers["host"] = endpoint.host;
    request.headers["Content-Type"] = "application/json";
    request.headers["Content-Length"] = Buffer.byteLength(request.body);

    const credentials = {
      accessKeyId: AWS.config.credentials.accessKeyId,
      secretAccessKey: AWS.config.credentials.secretAccessKey,
      sessionToken: AWS.config.credentials.sessionToken,
    };
    const signer = new AWS.Signers.V4(request, "es");
    signer.addAuthorization(credentials, new Date());

    const client = new AWS.HttpClient();
    client.handleRequest(
      request,
      null,
      function (response) {
        let responseBody = "";
        response.on("data", function (chunk) {
          responseBody += chunk;
        });
        response.on("end", function (chunk) {
          let parseResponse = JSON.parse(responseBody);
          if (typeof parseResponse.error !== "undefined") {
            reject(
              "GM_ERROR_OPENSEARCH: " +
                parseResponse.error.type +
                ": OpenSearch Response: " +
                responseBody
            );
          } else {
            resolve(parseResponse);
          }
        });
      },
      function (error) {
        reject("GM_ERROR_OPENSEARCHCLIENT_REJECT_QUERY: " + error);
      }
    );
  });
}

/* Utility Functions */
function isPresent(o) {
  return typeof o !== "undefined" && o != null ? true : false;
}

function isPrefix(s3EventKey) {
  if(typeof s3EventKey !== 'undefined' && s3EventKey != null && s3EventKey != "" ) {
    return (s3EventKey.length - 1 == s3EventKey.lastIndexOf("/")) ? true : false;
  }
  return false;
}

function formatMsg(unformattedJSONString) {
  try {
    return unformattedJSONString.replace(/\\/g, "");
  } catch (error) {
    throw new Error(
      error.toString() + " for unformattedJSONString: " + unformattedJSONString
    );
  }
}

// Escape and non-standard filesystem naming characters per 'https://www.w3schools.com/tags/ref_urlencode.ASP'
function escapeS3Key(s3Key) {
  try {
    s3Key = s3Key.trim();
    const searchPlus = "\\+";
    const searchRegExp = new RegExp(searchPlus, "g");
    return decodeURIComponent(s3Key.replace(searchRegExp, "%20"));
  } catch (error) {
    throw new Error(error.toString() + ": for key: " + s3Key);
  }
}

function logResult(resultdata, itemkey) {
  try {
    if (
      resultdata != null &&
      resultdata != "" &&
      typeof resultdata !== "undefined"
    ) {
      if (resultdata.result == "updated") {
        console.log("GM_SUCCESS_UPDATED_RECORD :", itemkey);
      } else if (resultdata.result == "created") {
        console.log("GM_SUCCESS_CREATED_RECORD :", itemkey);
      } else {
        console.log("GM_SUCCESS_UNKNOWN_RECORD_ACTION :", itemkey);
      }
    } else {
      console.error(
        "GM_ERROR_RESULT_DATA: ",
        itemkey,
        JSON.stringify(resultdata)
      );
    }
  } catch (error) {
    throw new Error(
      "GM_ERROR_LOGRESULT: " +
        error.toString() +
        ": for key: " +
        itemkey +
        " : for resultdata: " +
        resultdata
    );
  }
}
