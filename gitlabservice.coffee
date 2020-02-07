gitlabservice = {name: "gitlabservice"}
############################################################
#region logPrintFunctions
log = (arg) ->
    if allModules.debugmodule.modulesToDebug["cloudservicemodule"]?  then console.log "[gitlabservice]: " + arg
    return
ostr = (o) -> JSON.stringify(o, null, 4)
olog = (o) -> log "\n" + ostr(o)
printError = (msg) -> console.log(c.red("\n" + msg))
printSuccess = (msg) -> console.log(c.green("\n" + msg))
#endregion

############################################################
#region modulesFromEnvironment
Gitlab  = require('gitlab').Gitlab
c       = require('chalk')

############################################################
urlHandler = null
globalScope = null
#endregion

############################################################
gitlabservice.initialize = () ->
    log "gitlabservice.initialize"
    urlHandler = allModules.urlhandlermodule
    globalScope = allModules.globalscopemodule
    return

############################################################
#region internalFunctions
getGitlab = (host, token) ->
    log "getGitlab"
    options =
        host: host
        token: token
    return new Gitlab(options)
    
checkAccess = (service) ->
    log "checkAccess" 
    gitlab = getGitlab(service.hostURL, service.accessToken)       
    try
        options = 
            username: service.username
            maxPages: 1
        await gitlab.Users.all(options)
        return true
    catch err then return false

############################################################
#region retrieveAllFunctions
retrieveAllRepositories = (service) ->
    log "retrieveAllRepositories"
    gitlab = getGitlab(service.hostURL, service.accessToken)       
    options = 
        owned: true
        simple: true
        perPage: 100
        maxPages: 1000    
    data = await gitlab.Projects.all(options)
    return data.map((project) -> project.name)

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
#region retrieveSingleIds
getDeletableProjectID = (projects, service, repo) ->
    log "selectDeletableProject"
    pathWithNamespace = service.username + "/" + repo
    for project in projects
        if project.path_with_namespace.toLowerCase() == pathWithNamespace.toLowerCase()
            return project.id
    
    debugMessage = "\n@" + pathWithNamespace + "\n" + ostr(projects) 
    throw "getDeletableProjectID: did not find deletable project!" + debugMessage

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
#endregion

############################################################
#region repoManipulations
createRepository = (service, repo, visible) ->
    log "createRepository"
    gitlab = getGitlab(service.hostURL, service.accessToken)       
    
    if visible then visibility = "public"
    else visibility = "private"

    options = 
        name: repo
        visibility: visibility 
    await gitlab.Projects.create(options)
    return

deleteRepository = (service, repo) ->
    log "deleteRepository"
    gitlab = getGitlab(service.hostURL, service.accessToken)       
    
    options = 
        search: repo
        owned: true
        simple: true

    projects = await gitlab.Projects.all(options)
    if projects.length == 0 then return
    # olog projects
    id = getDeletableProjectID(projects, service, repo)
    # log id
    result = await gitlab.Projects.remove(id)
    # olog result
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
gitlabservice.check = (service) ->
    log "gitlabservice.check"
    service.isAccessible = await checkAccess(service)
    if service.isAccessible
        scope = await retrieveAllRepositories(service)
        globalScope.addServiceScope(scope, service)
    return

############################################################
#region repoManipulations
gitlabservice.deleteRepository = (service, repo) ->
    await deleteRepository(service, repo)
    return

gitlabservice.createRepository = (service, repo, visible) ->
    await createRepository(service, repo, visible)
    return

############################################################
gitlabservice.addDeployKey = (service, repoName, pubKey, title) ->
    await addDeployKey(service, repoName, pubKey, title)
    return

gitlabservice.removeDeployKey = (service, repoName, title) ->
    await removeDeployKey(service, repoName, title)
    return

############################################################
gitlabservice.addWebhook = (service, repoName, url, secret) ->
    await addWebhook(service, repoName, url, secret)
    return

gitlabservice.removeWebhook = (service, repoName, url) ->
    await removeWebhook(service, repoName, url)
    return
#endregion

############################################################
gitlabservice.getSSHURLBase = (service) ->
    log "gitlabservice.getSSHURLBase"
    serverName = urlHandler.getServerName(service.hostURL)
    return "git@" + serverName + ":" + service.username

gitlabservice.getHTTPSURLBase = (service) ->
    log "gitlabservice.getHTTPSURLBase"
    return service.hostURL + "/" + service.username
#endregion

module.exports = gitlabservice