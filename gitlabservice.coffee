gitlabservice = {name: "gitlabservice"}

#region modulesFromEnvironment
#region node_modules
Gitlab  = require('gitlab').Gitlab
c       = require('chalk')
#endregion

#region localModules
urlHandler = null
globalScope = null
#endregion
#endregion

#region logPrintFunctions
##############################################################################
log = (arg) ->
    if allModules.debugmodule.modulesToDebug["cloudservicemodule"]?  then console.log "[gitlabservice]: " + arg
    return
ostr = (o) -> JSON.stringify(o, null, 4)
olog = (o) -> log "\n" + ostr(o)
printError = (msg) -> console.log(c.red("\n" + msg))
printSuccess = (msg) -> console.log(c.green("\n" + msg))
#endregion
##############################################################################
gitlabservice.initialize = () ->
    log "gitlabservice.initialize"
    urlHandler = allModules.urlhandlermodule
    globalScope = allModules.globalscopemodule
    return

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

getDeletableProjectID = (projects, service, repo) ->
    log "selectDeletableProject"
    pathWithNamespace = service.username + "/" + repo
    for project in projects
        if project.path_with_namespace.toLowerCase() == pathWithNamespace.toLowerCase()
            return project.id
    
    debugMessage = "\n@" + pathWithNamespace + "\n" + ostr(projects) 
    throw "getDeletableProjectID: did not find deletable project!" + debugMessage

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

#endregion

#region exposedFunctions
gitlabservice.check = (service) ->
    log "gitlabservice.check"
    service.isAccessible = await checkAccess(service)
    if service.isAccessible
        scope = await retrieveAllRepositories(service)
        globalScope.addServiceScope(scope, service)
    return

gitlabservice.deleteRepository = (service, repo) ->
    await deleteRepository(service, repo)
    return

gitlabservice.createRepository = (service, repo, visible) ->
    await createRepository(service, repo, visible)
    return

gitlabservice.getSSHURLBase = (service) ->
    log "gitlabservice.getSSHURLBase"
    serverName = urlHandler.getServerName(service.hostURL)
    return "git@" + serverName + ":" + service.username

gitlabservice.getHTTPSURLBase = (service) ->
    log "gitlabservice.getHTTPSURLBase"
    return service.hostURL + "/" + service.username
#endregion

module.exports = gitlabservice