
// Mock event
const event = require('./localDeleteFolderTestEvent')

// Mock environment variables
process.env.AWS_REGION = 'us-west-2'
process.env.language = 'en'
process.env.domain = 'os-endpoint.graymeta.com'

// Lambda handler
const { handler } = require('./app')

const main = async () => {
  console.time('localDeleteTest')
  await handler(event)
  console.timeEnd('localDeleteTest')
}

main().catch(error => console.error(error))