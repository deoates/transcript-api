gcloud = require('gcloud')
fs = require('fs')
multiparty = require('multiparty')
Mimer = require('mimer')
express = require('express')
cors = require('cors')
morgan = require('morgan')

ffmpeg = require('fluent-ffmpeg')
command = ffmpeg('test.mp3', (err, meta) ->
  console.dir(meta)
)

bodyParser = require('body-parser')

app = express()
app.use express.static(__dirname + '/public')
app.set 'port', process.env.PORT || 8080

app.use cors()
app.use bodyParser.json()
app.use bodyParser.urlencoded({ extended: true })
app.use morgan('tiny')

app.use (err, req, res, next) ->
  console.error err.stack
  res.status(500).send 'Something broke!'

app.listen app.get('port'), ->
  console.log 'App is running on port: ' + app.get('port')

# STRIPE
publishableStripeKey = 'pk_live_hsLlDsQtfXsdbHWWpiWjoJd2'
secretStripeKey = 'sk_live_PW91KQpJVLgZSOOBcrCpkYKa'
stripe = require("stripe")(secretStripeKey)

app.get '/stripeKey', (req, res) ->
  res.status(200).send(publishableStripeKey)

app.post '/order', (req, res) ->
  
  amount = req.param('amount')
  token = req.param('token')
  email = req.param('email')
  files = req.param('files')
  length = req.param('length')

  charge = stripe.charges.create 
    amount: amount
    currency: "usd"
    card: token
    metadata:
      'email': email
      'files': files
      'length': length
    description: length + " audio transcription"
  , (err, charge) ->
    if err 
      console.log err
      if err.type is 'StripeCardError' 
        res.status(400).send('Payment declined')
    else
      console.log charge
      res.status(200).send('Payment successful!')

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

