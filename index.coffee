gcloud = require('gcloud')
http = require('http')
fs = require('fs')
multiparty = require('multiparty')
Mimer = require('mimer')
express = require('express')
cors = require('cors')

bodyParser = require('body-parser')

app = express()
app.use express.static(__dirname + '/public')
app.set 'port', process.env.PORT || 5000

app.use cors()
app.use bodyParser.json()
app.use bodyParser.urlencoded({ extended: true })

server = http.createServer(app)
server.listen(app.get('port'))
console.log server.address()

# stripe

stripeKey = "pk_live_hsLlDsQtfXsdbHWWpiWjoJd2"


if app.get('host') is "localhost" 
  stripeKey = "pk_test_ScjtJxkUb5VrbwH0Xdx0K8Ej"

stripe = require("stripe")(stripeKey)

app.get '/stripeKey', (req, res) ->
  res.send(stripeKey)


app.post '/order', (req, res) ->
  
  amt = req.param('amt')
  card = req.param('card')
  email = req.param('email')

  console.log amt, card, email

  return

  stripe.charges.create
    amount: amt
    currency: "usd"
    card: card
    description: "Charge: #{email}"
    metadata:
      'email': email
  , (err, charge) ->
    console.log err, charge


storage = gcloud.storage
  keyFilename: 'keys.json'
  projectId: '367709922404'

bucket = storage.bucket('transcript-engine')

app.post '/upload', (req, res) ->

  form = new multiparty.Form(autoFile: false)

  form.on 'close', ->
    res.send 200

  form.on 'error', (err) ->
    statusCode = err.statusCode || 404
    res.status(statusCode)
    return

  form.on 'part', (part) ->

    part.on 'error', (err) ->
      statusCode = err.statusCode || 404
      res.status(statusCode)
      return

    fileType = '.' + part.filename.split('.').pop().toLowerCase()
    fileName = "#{Date.now()}-#{part.filename}"
    console.log fileName

    options =
      resumable: true
      validation: 'crc32c'
      metadata:
        contentType: Mimer(fileType)
    
    # clear out the part's headers to prevent conflicting data being passed to GCS
    part.headers = null

    # create/select file in GC bucket
    file = bucket.file(fileName)

    # start streaming file
    part.pipe(file.createWriteStream(options)).on 'error', (err) ->
      console.log(err)


  try
    form.parse req
  catch err
    console.log err

