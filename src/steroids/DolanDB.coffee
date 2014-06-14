restify = require "restify"
util = require "util"
yaml = require 'js-yaml'
Login = require "./Login"
q = require "q"
fs = require "fs"
URL = require "url"
http = require 'http'
open = require "open"
exec = require('child_process').exec
ejs = require('ejs')
paths = require "./paths"
env = require("yeoman-generator")()

data_definition_path = 'config/dolandb.yaml'
raml_path            = 'www/local.raml'

#dolan_db_base_url = "http://datastorage-api.local.devgyver.com:3000/"
#db_browser_url = 'http://localhost:3001'

dolan_db_base_url    = 'http://datastorage-api.devgyver.com'
dolan_db_url         = "#{dolan_db_base_url}/v1/datastorage"
db_browser_url       = 'http://dolandb-browser.devgyver.com'
configapi_url        = 'http://config-api.local.testgyver.com:3000'

###

  NOTE:

  devroids login --authUrl="http://accounts.testgyver.com"

###

# not needed anymore
request = require('request-json')
DbBrowser = request.newClient(db_browser_url)

class DolanDB
  getAppId: () =>
    5951
    #12165
    # replace this with the real thing
    # getFromCloudJson('id')

  constructor: (@options={}) ->
    ## deprecated?
    @dolandbCredentialApi = restify.createJsonClient
      url: dolan_db_base_url
    @dolandbCredentialApi.basicAuth Login.currentAccessToken(), 'X'

    @composer = restify.createJsonClient
      url: configapi_url
    @composer.headers["Authorization"] = Login.currentAccessToken()

    @db_browser = restify.createJsonClient
      url: db_browser_url

  getConfig = () ->
    yaml.safeLoad readConfigFromFile()

  readConfigFromFile = () ->
    try return fs.readFileSync(data_definition_path, 'utf8')
    catch e
      console.log "you must first init dolandb with command 'steroids dolandb init'"
      process.exit 1

  noServiceProvider = (err) ->
    return false unless err?
    JSON.parse(err.message).error == 'service provider not found'

  getIdentificationHash = ->
    getFromCloudJson('identification_hash')

  getFromCloudJson = (param) ->
    cloud_json_path = "config/cloud.json"

    unless fs.existsSync(cloud_json_path)
      console.log "application needs to be deployed before provisioning a dolandb, please run steroids deploy"
      process.exit 1

    cloud_json = fs.readFileSync(cloud_json_path, 'utf8')
    cloud_obj = JSON.parse(cloud_json)
    return cloud_obj[param]

  getLocalRaml = ->
    fs.readFileSync(raml_path, 'utf8')

  test: (params) =>
    ###
      workflow:
        ensure that a uniq appid in cloud.json

        dolandb init (provisions a db using dolan provision api)

        test provider
            initializes a dolan db-provider in config-api
        test resource beer name:string brewery:string
            initializes a resource in config-api
        test raml
            gets a raml and writes it to www/local.raml

        test sync
            opens (and syncs) dolandb browser

        yo devroids:dolan-res beer name brewery alcohol
          generates a crud app

        update application.coffee to point to created resources

        other:

        test resources    lists your defined resources
        test scaffold     shows commands to scaffold code templates
        test my           shows defined providers
        test remote <id>  removes provider with <id>
        test all          show all existing providers

    ###

    com = params.shift()

    if com=='provider'

      config = getConfig()

      if config.resourceProviderUid?
        console.log 'doland db provider exists already'
        process.exit 1

      data =
        providerTypeId: 6,
        name: config['bucket']
        configurationKeys:
          bucket_id: config['bucket_id']
          steroids_api_key: config['apikey']

      @composer.post("/app/#{@getAppId()}/service_providers.json", data, (err, req, res, obj) =>
        # exists already? next line not needed
        #congig = getConfig()
        config.resourceProviderUid = obj['uid']

        fs.writeFile(data_definition_path, yaml.safeDump(config), (err,data) ->
          console.log 'dolandb resource provider created'
        )
      )

    if com=="resource"
      resource_name = params.shift()

      config = getConfig()

      provider = config.resourceProviderUid
      bucket = config.bucket

      url = "/app/#{@getAppId()}/service_providers/#{provider}/resources.json"

      data =
        name: resource_name
        path: bucket+'/'+resource_name
        columns: []

      params.forEach (param) ->
        [k, v] = param.split(':')
        data.columns.push { name:k, type:v}

      @composer.post(url, data, (err, req, res, obj) =>
        if noServiceProvider(err)
          console.log "service provider is not defined"
          console.log "run first 'devroids dolandb test provision'"
        else
          console.log "resource #{resource_name} defined"
          scaffold = "you can scaffold code skeleton by running 'yo devroids:dolan-res #{resource_name} #{params.join(' ')} defined'"
          console.log scaffold
          ## perhaps raml should be synched???
        @composer.close()
      )

    if com=="raml"
      @composer.headers["Accept"] = "text/yaml"
      url = "/app/#{@getAppId()}/raml?identification_hash=#{getIdentificationHash()}"

      @composer.get(url, (err, req, res, obj) =>
        raml_file_content = res['body']
        @composer.close()
        fs.writeFile(raml_path, raml_file_content, (err,data) ->
          console.log 'raml saved'
        )
      )

    if com=='sync'
      raml = getLocalRaml()

      config = getConfig()

      if config.browser_id?
        # browser instance exists
        @db_browser.put("/ramls/#{config.browser_id}", { raml: { content:raml } }, (err, req, res, obj) =>
          @db_browser.close()
          open URL.format("#{db_browser_url}/#browser/#{config.browser_id}")
        )

      else
        # create a new browser instance
        post_data =
          content: raml
          bucket_id: config.bucket_id
          application_name: 'my great app'

        @db_browser.post('/ramls', { raml: post_data }, (err, req, res, obj) =>
          @db_browser.close()

          config.browser_id = obj.id
          open URL.format("#{db_browser_url}/#browser/#{config.browser_id}")
          fs.writeFileSync(data_definition_path, yaml.safeDump(config))
        )

    if com=='all'
      @composer.get('/available_service_providers.json', (err, req, res, obj) =>
        console.log obj
        @composer.close()
      )

    if com=='my'
      @composer.get("/app/#{@getAppId()}/service_providers.json", (err, req, res, obj) =>
        if obj.length==0
          console.log 'no providers defined'
        else
          console.log obj
        @composer.close()
      )

    if com=='remove_provider'
      id = params.shift()

      @composer.del("/app/#{@getAppId()}/service_providers/#{id}.json", data, (err, req, res, obj) =>
        console.log 'provider removed'
        @composer.close()
      )

    if com=='loll'
      config = getConfig()
      id = config.resourceProviderUid

      @composer.get("/app/#{@getAppId()}/service_providers/#{id}/resources.json", (err, req, res, obj) =>
        console.log err
        console.log obj
        @composer.close()
      )

    if com=='resources'
      config = getConfig()
      provider = config.resourceProviderUid

      @composer.get("/app/#{@getAppId()}/service_providers/#{provider}/resources.json", (err, req, res, obj) =>
        obj.forEach (resource) ->
          console.log resource.name
          resource.columns.forEach (column) ->
            console.log " #{column.name}:#{column.type}"

        @composer.close()
      )

    if com=='scaffold'
      config = getConfig()
      provider = config.resourceProviderUid

      @composer.get("/app/#{@getAppId()}/service_providers/#{provider}/resources.json", (err, req, res, obj) =>
        console.log "you can scaffold code skeletons by running"
        obj.forEach (resource) ->
          columns = resource.columns.map (column) -> column.name
          arg = "#{resource.name} #{columns.join(' ')}"
          console.log "yo devroids:dolan-res #{arg}"

        @composer.close()
      )

  ## old ->

  test3: (params) =>
    @createBucketWithCredentials(params[0])
    .then(
      (data) =>
        console.log data
        console.log "u:  "+data.body.login
        console.log "pw: "+data.body.password
        console.log "id: "+data.body.datastore_bucket_id
      , (err) =>
        console.log '.'
        console.log err
        console.log JSON.stringify(err.body)
    )

  test2: () =>
    env.plugins "node_modules", paths.npm
    env.lookup '*:*'
    env.run "devroids:dolan-res", () ->
    #env.run "devroids:app lol", () ->
      console.log 'ME'

  drop: () =>
    fs.unlink(data_definition_path, () ->
      # destroy db credentials
      console.log 'database dropped'
    )

  initialize: (options={}) =>
    console.log 'initializing DolanDB...'

    if fs.existsSync(data_definition_path)
      console.log "file #{data_definition_path} exists!"
      return

    name = "db#{@getAppId()}"

    @createBucketWithCredentials(name)
    .then(
      (bucket) =>
        @createDolandbConfig("#{bucket.login}#{bucket.password}", name, bucket.datastore_bucket_id)
    ).then(
      () =>
        console.log "dolandb initialized"
        console.log "create resources with 'steroids dolandb resource', eg:"
        console.log "  steroids dolandb resource beer name:string brewery:string alcohol:integer drinkable:boolean"
        @dolandbCredentialApi.close()
      , (err) ->
        console.log JSON.stringify err
        @dolandbCredentialApi.close()
    )

  resource: (params) =>
    resource_name = params.shift()

    doc = yaml.safeLoad(fs.readFileSync(data_definition_path, 'utf8'))

    properties = {}
    params.forEach (param) ->
      [k, v] = param.split(':')
      properties[k] = v

    res = {}
    res[resource_name]  = properties

    doc.resources.push res

    fs.writeFile(data_definition_path, yaml.safeDump(doc), (err,data) ->
      console.log 'resource created'
    )

  scaffold: (resources) =>
    doc = yaml.safeLoad(fs.readFileSync(data_definition_path, 'utf8'))
    doc.resources.forEach( (resource) =>
      @run_scaffold_for(resource) if resources.length==0 or Object.keys(resource)[0] in resources
    )

  create_or_update: () =>
    @generate_raml_file()
    .then => @uploadRamlToBrowser()
    .then => @openRamlBrowser()

  open: (options = {}) =>
    console.log 'open'
    unless fs.existsSync(data_definition_path)
      console.log "intialize the database first with 'steroids dolandb init'"
      console.log "... define resources with 'steroids dolandb resource'"
      console.log "... and create the database using 'steroids create"
      return

    doc = yaml.safeLoad(fs.readFileSync(data_definition_path, 'utf8'))
    unless (doc.browser_id)
      console.log "run first 'steroids create"
      return

    @openRamlBrowser()

  ## helpers

  run_scaffold_for: (resource) =>
    args = create_yo_generator_args_for(resource)
    name = Object.keys(resource)[0]

    console.log "running:"
    console.log "  yo devroids:dolan-res #{args}"
    console.log ""

    env.plugins "node_modules", paths.npm
    env.lookup '*:*'
    env.run "devroids:dolan-res #{args}", () ->
      console.log "=============="
      console.log 'you'
      console.log "resource will be located in 'http://localhost/views/#{name}/index.html' "
    #exec("yo devroids:dolan-res #{args}", (error, stdout, stderr) ->
    #)

  validateName = (string) =>
    valid = /^[a-z_]*$/
    return true if string.match valid

    console.log "only lowcase alphabeths and underscore allowed: '#{string}'"
    process.exit 1

  validateType = (string) =>
    allowed = ["string", "integer", "boolean", "number", "date"]
    return true if string in allowed

    console.log "type '#{string}' not within allowed: #{allowed.join(', ')}"
    process.exit 1

  nameTakenError = (err) ->
    response = JSON.parse(err.message)
    return false if response.errors.name==undefined
    'has already been taken' in response.errors.name

  createBucketWithCredentials: (name) =>
    deferred = q.defer()

    data =
      dbName: name
      appId: 12165  ## get this from confs
      #apiKey: Login.currentAccessToken()

    @dolandbCredentialApi.post('/v1/credentials/provision', { data: data }, (err, req, res, obj) =>
      if obj.code==201
        deferred.resolve(obj.body)
      else
        deferred.reject(obj)
    )

    return deferred.promise

  createDolandbConfig: (apikey, database, bucket_id) =>
    deferred = q.defer()

    name = 'name of the app'

    doc =
      name: name
      apikey: apikey
      bucket: database
      bucket_id: bucket_id
      resources: []

    fs = require('fs')
    fs.writeFile(data_definition_path, yaml.safeDump(doc), (err,data) ->
      deferred.resolve()
    )
    return deferred.promise

  create_yo_generator_args_for = (resource) ->
    name = Object.keys(resource)[0]
    properties = resource[name]
    resourceString = name

    for prop in Object.keys properties
      resourceString += " #{prop}"

    return resourceString

  generate_raml_file: () =>
    deferred = q.defer()
    doc = yaml.safeLoad(fs.readFileSync(data_definition_path, 'utf8'))
    doc.base_url = "#{dolan_db_url}/#{doc.bucket}"

    raml_template = fs.readFileSync(__dirname + '/_raml.ejs', 'utf8');
    raml_file_content = ejs.render(raml_template, doc)

    stream = fs.createWriteStream(raml_path)
    stream.once('open', (fd) ->
      stream.write raml_file_content
      stream.end()
      deferred.resolve()
    )


    return deferred.promise

  openRamlBrowser: () =>
    doc = yaml.safeLoad(fs.readFileSync(data_definition_path, 'utf8'))
    open URL.format("#{db_browser_url}/#browser/#{doc.browser_id}")

  uploadRamlToBrowser: () =>
    deferred = q.defer()
    raml = fs.readFileSync(raml_path, 'utf8')

    doc = yaml.safeLoad(fs.readFileSync(data_definition_path, 'utf8'))
    if doc.browser_id?
      # browser instance exists
      DbBrowser.put("ramls/#{doc.browser_id}", {raml:{content:raml} }, (err, res, body) =>
        deferred.resolve()
      )
    else
      # create a new broser instance
      post_data =
        content: raml
        bucket_id: doc.bucket_id
        application_name: 'myapp'

      DbBrowser.post('ramls', { raml:post_data }, (err, res, body) =>
        doc.browser_id = body.id
        fs.writeFile(data_definition_path, yaml.safeDump(doc), (err,data) =>
          deferred.resolve()
        )
      )
    return deferred.promise

module.exports = DolanDB
