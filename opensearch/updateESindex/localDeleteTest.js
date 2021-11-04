
// Mock event
const event = require('./localDeleteTestEvent')

// Mock environment variables
process.env.AWS_REGION = 'us-west-2'
process.env.localTest = true
process.env.language = 'en'
process.env.OutputBucket = 'iris-aws-dev'
process.env.domain = 'os-endpoint.graymeta.com'

// Lambda handler
const { handler } = require('./app')

const main = async () => {
  console.time('localCreateTest')
  await handler(event)
  console.timeEnd('localCreateTest')
}

main().catch(error => console.error(error))