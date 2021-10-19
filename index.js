const AWS = require('aws-sdk')
AWS.config.update({ region: process.env.AWS_REGION })
const s3 = new AWS.S3()
const URL_EXPIRATION_SECONDS = 100

import crypto from 'crypto'
import { promisify } from "util"
const randomBytes = promisify(crypto.randomBytes)

exports.handler = async (event) => {
	let jsonResponse = await getUploadURL(event)
  
  
  let response = {
        statusCode: 200,
        body: jsonResponse,
        headers:{ 'Access-Control-Allow-Origin' : '*' }
    
  };
  return response;
}

const getUploadURL = async function(event) {
  // const randomID = parseInt(Math.random() * 10000000)

  //event.queryStringParameters.q
  const rawBytes = await randomBytes(16)
  const randomID = rawBytes.toString('hex')
  const Key = `${randomID}.jpg`

  // Get pre-signed URL from S3
  const s3Params = {
    Bucket: process.env.UploadBucket,
    Key,
    Expires: URL_EXPIRATION_SECONDS,
    ContentType: 'image/jpeg'
  }
  const uploadURL = await s3.getSignedUrlPromise('putObject', s3Params)
  return JSON.stringify({
    uploadURL: uploadURL,
    Key
  })
}

