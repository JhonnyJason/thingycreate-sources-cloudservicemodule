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
        userId = await getCurrentUserId(service)
        if !service.userId then service.userId = userId
        else if service.userId != userId then throw new Error("No userId match!")
        return true
    catch err then return false

getRepoIdString = (service, repo) ->
    return service.username + "/" + repo
    # return service.username + "%2F" + repo
    
############################################################
#region retrieveAllFunctions
retrieveAllRepositories = (service) ->
    log "retrieveAllRepositories"
    gitlab = getGitlab(service.hostURL, service.accessToken)       
    options = 
        owned: true
        simple: true
        perPage: 100
        maxPages: 100    
    data = await gitlab.Users.projects(service.userId, options)
    return data.map((project) -> project.name)

retrieveAllDeployKeys = (service, repo) ->
    gitlab = getGitlab(service.hostURL, service.accessToken)       
    stringId = getRepoIdString(service, repo)
    options = 
        projectId: stringId
        perPage: 100
        maxPages: 100
    return await gitlab.DeployKeys.all(options)

retrieveAllWebhooks = (service, repo) ->
    gitlab = getGitlab(service.hostURL, service.accessToken)       
    stringId = getRepoIdString(service, repo)
    options = 
        perPage: 100
        maxPages: 100
    return await gitlab.ProjectHooks.all(stringId, options)

#endregion

############################################################
#region retrieveSingleIds
getDeletableProjectID = (projects, service, repo) ->
    pathWithNamespace = service.username + "/" + repo
    for project in projects
        if project.path_with_namespace.toLowerCase() == pathWithNamespace.toLowerCase()
            return project.id
    
    debugMessage = "\n@" + pathWithNamespace + "\n" + ostr(projects) 
    throw "getDeletableProjectID: did not find deletable project!" + debugMessage

getDeployKeyId = (service, repo, title) ->
    log "getDeployKeyId"
    allKeys = await retrieveAllDeployKeys(service, repo)
    olog allKeys
    for key in allKeys
        return key.id if title == key.title
    throw new Error("No deployKey found! title: " + title)

getWebhookId = (service, repo, url) ->
    allHooks = await retrieveAllWebhooks(service, repo)
    # olog allHooks
    for hook in allHooks
        return hook.id if url == hook.url
    throw new Error("No Webhook found! url: " + url)

getCurrentUserId = (service) ->
    gitlab = getGitlab(service.hostURL, service.accessToken)       
    user = await gitlab.Users.current()
    return user.id

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
    gitlab = getGitlab(service.hostURL, service.accessToken)
    stringId = getRepoIdString(service, repo)
    options = 
        title: title
        key: key
    await gitlab.DeployKeys.add(stringId, options)
    return
    
removeDeployKey = (service, repo, title) ->
    log "removeDeployKey"
    gitlab = getGitlab(service.hostURL, service.accessToken)       
    stringId = getRepoIdString(service, repo)
    keyId = await getDeployKeyId(service, repo, title)
    log "on repo with stringId: " + stringId
    log "trying to remove deploy key with keyId: " + keyId
    await gitlab.DeployKeys.remove(stringId, keyId)
    return

############################################################
addWebhook = (service, repo, url, secret) ->
    log "addWebhook"
    gitlab = getGitlab(service.hostURL, service.accessToken)       
    stringId = getRepoIdString(service, repo)
    options = 
        push_events: true
        token: secret
    await gitlab.ProjectHooks.add(stringId, url, options)
    return

removeWebhook = (service, repo, url) ->
    log "removeWebhook"
    gitlab = getGitlab(service.hostURL, service.accessToken)       
    stringId = getRepoIdString(service, repo)
    hookId = await getWebhookId(service, repo, url)
    await gitlab.ProjectHooks.remove(stringId, hookId)
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