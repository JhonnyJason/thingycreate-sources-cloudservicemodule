githubservice = {name: "githubservice"}
############################################################
#region printLogFunctions
log = (arg) ->
    if allModules.debugmodule.modulesToDebug["cloudservicemodule"]?  then console.log "[githubservice]: " + arg
    return
ostr = (o) -> JSON.stringify(o, null, 4)
olog = (o) -> log "\n" + ostr(o)
printError = (msg) -> console.log(c.red("\n" + msg))
printSuccess = (msg) -> console.log(c.green("\n" + msg))
#endregion

############################################################
#region modulesFromEnvironment
{Octokit} = require("@octokit/rest")
c = require('chalk')

############################################################
globalScope = null
cfg = null
#endregion

############################################################
baseUrl = "https://api.github.com"
userAgent = ""

############################################################
githubservice.initialize = () ->
    log "githubservice.initialize"
    globalScope = allModules.globalscopemodule
    cfg = allModules.configmodule
    userAgent = cfg.cli.name + " v" + cfg.cli.version
    return
    
############################################################
#region internalFunctions
getOctokit = (token) ->
    log "getOctokit"
    options =
        auth: token
        userAgent: userAgent
        baseUrl: baseUrl
    return Octokit(options)

checkAccess = (token) ->
    log "checkAccess"
    octokit = getOctokit(token)
    try
        info = await octokit.users.getAuthenticated()
        return true
    catch err then return false

############################################################
#region retrieveAllFunctions
retrieveAllRepositories = (service) ->
    log "retrieveAllRepositories"
    octokit = getOctokit(service.accessToken)
    options = 
        owner: service.username
        visibility: "all"
        affiliation: "owner"
        sort: "updated"
        per_page: 100
        direction: "asc"
        page: 0

    results = []
    loop
        answer = await octokit.repos.list(options)
        data = answer.data
        names = (repo.name for repo in data)
        options.page++    
        if names.length then results = results.concat(names)
        else return results
    return

retrieveAllDeployKeys = (service, repo) ->
    log "retrieveAllDeployKeys"
    octokit = getOctokit(service.accessToken)
    options = 
        owner: service.username
        repo: repo
        per_page: 100
        page: 0

    results = []
    loop
        answer = await octokit.repos.listDeployKeys(options)
        keys = answer.data
        # keys =  (key for key in data)
        options.page++    
        if keys.length then results = results.concat(keys)
        else return results
    return

retrieveAllWebhooks = (service, repo) ->
    log "retrieveAllWebhooks"
    octokit = getOctokit(service.accessToken)
    options = 
        owner: service.username
        repo: repo
        per_page: 100
        page: 0
    results = []
    loop
        answer = await octokit.repos.listHooks(options)
        hooks = answer.data
        # hooks =  (hook for hook in data)
        options.page++    
        if hooks.length then results = results.concat(hooks)
        else return results
    return
#endregion

############################################################
getDeployKeyId = (service, repo, title) ->
    allKeys = await retrieveAllDeployKeys(service, repo)
    # olog allKeys
    for key in allKeys
        return key.id if title == key.title
    throw new Error("No deployKey found! title: " + title)

getWebhookId = (service, repo, url) ->
    allHooks = await retrieveAllWebhooks(service, repo)
    # olog allHooks
    for hook in allHooks
        return hook.id if url == hook.config.url
    throw new Error("No Webhook found! url: " + url)

############################################################
#region repoManipulation
createRepository = (service, repo, visible) ->
    log "createRepository"
    octokit = getOctokit(service.accessToken)
    options = 
        name: repo
        private: !visible
    await octokit.repos.createForAuthenticatedUser(options)
    return

deleteRepository = (service, repo) ->
    log "deleteRepository"
    octokit = getOctokit(service.accessToken)
    options = 
        repo: repo
        owner: service.username
    await octokit.repos.delete(options)
    return

############################################################
addDeployKey  = (service, repo, key, title) ->
    log "addDeployKey"
    octokit = getOctokit(service.accessToken)
    options = 
        repo: repo
        owner: service.username
        key: key
        title: title
    await octokit.repos.addDeployKey(options)
    return
    
removeDeployKey = (service, repo, title) ->
    log "removeDeployKey"
    octokit = getOctokit(service.accessToken)
    keyId = await getDeployKeyId(service, repo, title)
    log "keyId: " + keyId
    options = 
        repo: repo
        owner: service.username
        key_id: keyId
    await octokit.repos.removeDeployKey(options)
    return
    
############################################################
addWebhook = (service, repo, url, secret) ->
    log "addWebhook"
    octokit = getOctokit(service.accessToken)
    config = 
        url: url
        content_type: "json"
        secret: secret
    options = 
        repo: repo
        owner: service.username
        config: config
        events: ["push"]
    await octokit.repos.createHook(options)
    return

removeWebhook = (service, repo, url) ->
    log "removeWebhook"
    octokit = getOctokit(service.accessToken)
    hookId = await getWebhookId(service, repo, url)
    log "hookId: " + hookId
    options = 
        repo: repo
        owner: service.username
        hook_id: hookId
    await octokit.repos.deleteHook(options)
    return
#endregion
#endregion

############################################################
#region exposedFunctions
githubservice.check = (service) ->
    log "githubservice.check"
    service.isAccessible = await checkAccess(service.accessToken)
    service.hostURL = baseUrl
    if service.isAccessible
        scope = await retrieveAllRepositories(service)
        globalScope.addServiceScope(scope, service)
    return

############################################################
#region repoManipulations
githubservice.deleteRepository = (service, repo) ->
    await deleteRepository(service, repo)
    return

githubservice.createRepository = (service, repo, visible) ->
    await createRepository(service, repo, visible)
    return

############################################################
githubservice.addDeployKey = (service, repoName, pubKey, title) ->
    await addDeployKey(service, repoName, pubKey, title)
    return

githubservice.removeDeployKey = (service, repoName, title) ->
    await removeDeployKey(service, repoName, title)
    return

############################################################
githubservice.addWebhook = (service, repoName, url, secret) ->
    await addWebhook(service, repoName, url, secret)
    return

githubservice.removeWebhook = (service, repoName, url) ->
    await removeWebhook(service, repoName, url)
    return
#endregion

############################################################
githubservice.getSSHURLBase = (service) ->
    log "githubservice.getSSHURLBase"
    return "git@github.com:" + service.username

githubservice.getHTTPSURLBase = (service) ->
    log "githubservice.getHTTPSURLBase"
    return "https://github.com/" + service.username
#endregion

module.exports = githubservice