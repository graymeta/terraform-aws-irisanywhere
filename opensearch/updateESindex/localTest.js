
// Mock event
const event = require('./localTestEvent')

// Mock environment variables
process.env.AWS_REGION = 'us-west-2'
process.env.localTest = true
process.env.language = 'en'
process.env.OutputBucket = 'iris-aws-dev'
process.env.domain = 'search-index-s3-iris-aws-dev-mcqnhh3vm2226xpi53neo4pzwu.us-west-2.es.amazonaws.com'

// Lambda handler
const { handler } = require('./app')

const main = async () => {
  console.time('localTest')
  await handler(event)
  console.timeEnd('localTest')
}

main().catch(error => console.error(error))