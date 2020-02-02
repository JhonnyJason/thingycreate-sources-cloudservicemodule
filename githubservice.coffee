githubservice = {name: "githubservice"}

#region node_modules
OctokitREST = require("@octokit/rest")
c       = require('chalk')
#endregion

#region internalProperties
baseUrl = "https://api.github.com"
userAgent = "thingycreate v0.3.0"

globalScope = null
#endregion

#region essentialFunctions
##############################################################################
#region logFunctions
log = (arg) ->
    if allModules.debugmodule.modulesToDebug["cloudservicemodule"]?  then console.log "[githubservice]: " + arg
    return
ostr = (o) -> JSON.stringify(o, null, 4)
olog = (o) -> log "\n" + ostr(o)
printError = (msg) -> console.log(c.red("\n" + msg))
printSuccess = (msg) -> console.log(c.green("\n" + msg))
#endregion
##############################################################################
githubservice.initialize = () ->
    log "githubservice.initialize"
    globalScope = allModules.globalscopemodule
    return
#endregion
    
#region internalFunctions
getOctokit = (token) ->
    log "getOctokit"
    options =
        auth: token
        userAgent: userAgent
        baseUrl: baseUrl
    return new OctokitREST(options)

checkAccess = (token) ->
    log "checkAccess"
    octokit = getOctokit(token)
    try
        info = await octokit.users.getAuthenticated()
        return true
    catch err then return false

retrieveAllRepositories = (service) ->
    log "retrieveAllRepositories"
    octokit = getOctokit(service.accessToken)
    options = 
        visibility: "all"
        affiliation: "owner"
        sort: "updated"
        per_page: 100
        direction: "asc"
        page: 0

    results = []
    loop
        answer = await octokit.repos.list(options)
        #else return resultskeys = Object.keys(answer)
        keys = Object.keys(answer)
        data = answer.data
        names = (repo.name for repo in data)
        options.page++    
        if names.length then results = results.concat(names)
        else return results
    return

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
#endregion

#region exposedFunctions
githubservice.check = (service) ->
    log "githubservice.check"
    service.isAccessible = await checkAccess(service.accessToken)
    service.hostURL = baseUrl
    if service.isAccessible
        scope = await retrieveAllRepositories(service)
        globalScope.addServiceScope(scope, service)
    return

githubservice.deleteRepository = (service, repo) ->
    await deleteRepository(service, repo)
    return

githubservice.createRepository = (service, repo, visible) ->
    await createRepository(service, repo, visible)
    return

githubservice.getSSHURLBase = (service) ->
    log "githubservice.getSSHURLBase"
    return "git@github.com:" + service.username

githubservice.getHTTPSURLBase = (service) ->
    log "githubservice.getHTTPSURLBase"
    return "https://github.com/" + service.username
#endregion

module.exports = githubservice