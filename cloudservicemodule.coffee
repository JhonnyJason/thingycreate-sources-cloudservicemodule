cloudservicemodule = {name: "cloudservicemodule"}
############################################################
#region logPrintFunctions
log = (arg) ->
    if allModules.debugmodule.modulesToDebug["cloudservicemodule"]?  then console.log "[cloudservicemodule]: " + arg
    return
olog = (o) -> log "\n" + ostr(o)
ostr = (o) -> JSON.stringify(o, null, 4)
#endregion

############################################################
#region modulesFromEnvironment
c = require("chalk")

############################################################
#region localModules
user = null
urlHandler = null
globalScope = null
userConfig = null
#endregion
#endregion

############################################################
#region serviceTypes
allCloudServiceTypes = 
    github:
        defaultHost: "https://api.github.com"
        module: require "./githubservice"
    gitlab:
        defaultHost: "https://gitlab.com"
        module: require "./gitlabservice"
    # bitbucket:
    #     defaultHost: "https://api.bitbucket.org/2.0"
    #     module: require "bitbucketservice"

allServiceTypes = Object.keys(allCloudServiceTypes)
#endregion

############################################################
cloudservicemodule.initialize = ->
    log "cloudservicemodule.initialize"
    globalScope = allModules.globalscopemodule
    userConfig = allModules.userconfigmodule
    urlHandler = allModules.urlhandlermodule
    user = allModules.userinquirermodule

    await m.module.initialize() for n,m of allCloudServiceTypes 
    return

############################################################
#region internalFunctions
getDefaultThingyCloudService = (type) ->
    log "getDefaultThingyCloudService"
    service = { 
        accessToken: ""
        username: ""
        hostURL: "" 
        type: type
        isAccessible: false
    }
    if allCloudServiceTypes[type]?
        service.hostURL = allCloudServiceTypes[type].defaultHost
    return service

createNewCloudService = (type) ->
    log "createNewCloudService"
    newCloudServiceObject = getDefaultThingyCloudService(type)
    return newCloudServiceObject
    
getStringProperties = (service) ->
    log "getStringProperties"
    properties = {}
    for label, content of service
        if label == "type" then continue
        if typeof content == "string" then properties[label] = content
    return properties


############################################################
serviceModule = (service) ->
    type = service.type
    return allCloudServiceTypes[type].module
    
############################################################
#region callsToServiceModule
############################################################
createRepository = (service, repoName, visible) ->
    log "createRepository"
    m = serviceModule(service)
    await m.createRepository(service, repoName, visible)
    return

deleteRepository = (service, repoName) ->
    log "deleteRepository"
    m = serviceModule(service)
    await m.deleteRepository(service, repoName)
    return

############################################################
addDeployKey = (service, repoName, pubKey, title) ->
    log "addDeployKey"
    m = serviceModule(service)
    await m.addDeployKey(service, repoName, pubKey, title)
    return

removeDeployKey = (service, repoName, title) ->
    log "removeDeployKey"
    m = serviceModule(service)
    await m.removeDeployKey(service, repoName, title)
    return

############################################################
addWebhook = (service, repoName, url, secret) ->
    log "addWebhook"
    m = serviceModule(service)
    await m.addWebhook(service, repoName, url, secret)
    return

removeWebhook = (service, repoName, url) ->
    log "removeWebhook"
    m = serviceModule(service)
    await m.removeWebhook(service, repoName, url)
    return
#endregion

############################################################
#region urlRelatedFunctions
getSSHURLBaseForUnknownService = (service) ->
    log "getSSHURLBaseForUnknownService"
    serverName = urlHandler.getServerName(service.hostURL)
    return "git@" + serverName + ":" + service.username

getHTTPSURLBaseForUnknownService = (service) ->
    log "getHTTPSURLBaseForUnknownService"
    serverName = urlHandler.getServerName(service.hostURL)
    return "https://" + serverName + "/" + service.username

sshURLBaseForService = (service) ->
    log "sshURLBaseForService"
    type = service.type
    if allCloudServiceTypes[type]?
        module = allCloudServiceTypes[type].module
        return module.getSSHURLBase(service)
    getSSHURLBaseForUnknownService(service)

httpsURLBaseForService = (service) ->
    log "httpsURLBaseForService"
    type = service.type
    if allCloudServiceTypes[type]?
        module = allCloudServiceTypes[type].module
        return module.getHTTPSURLBase(service)
    getHTTPSURLBaseForUnknownService(service)        

getServiceObjectFromURL = (url) ->
    log "getServiceObjectFromURL"
    services = userConfig.getAllServices()
    for service in services
        if serviceFitsURL(service, url)
            return service

    service = getDefaultThingyCloudService("unknown")
    service.hostURL = urlHandler.getHostURL(url)
    service.username = urlHandler.getRessourceScope(url)
    return service

serviceFitsURL = (service, url) ->
    log "serviceFitsURL"
    hostURL = urlHandler.getHostURL(url)
    ressourceScope = urlHandler.getRessourceScope(url)
    baseURL = hostURL + "/" + ressourceScope
    serviceBasePath = httpsURLBaseForService(service)
    return baseURL == serviceBasePath
#endregion

############################################################
#region serviceChoiceLabel
getServiceChoiceLabel = (service, index) ->
    log "getServiceChoiceLabel"
    label = "" + index + " " + service.username + " @ " + service.hostURL
    if !service.isAccessible then return c.red(label)
    return label

getServiceChoice = (service, index) ->
    log "getServiceChoice"
    label = getServiceChoiceLabel(service, index)
    choice = 
        name: label
        value: index
    return choice

getServiceChoices = (services) ->
    log "getServiceChoices"
    return (getServiceChoice(s,i) for s,i in services)

getAllServiceChoices = ->
    log "getAllServiceChoices"
    return getServiceChoices(userConfig.getAllServices())
#endregion
#endregion

############################################################
#region exposed
cloudservicemodule.check = (service) ->
    log "cloudservicemodule.checkService"
    m = serviceModule(service)
    await m.check(service)
    return

############################################################
#region interfaceForUserActions
cloudservicemodule.createConnection = () ->
    log "cloudservicemodule.createConnection"
    serviceType = await user.inquireCloudServiceType()
    if serviceType == -1 then return
    thingyCloudService = createNewCloudService(serviceType)
    await userConfig.addCloudService(thingyCloudService)
    return

cloudservicemodule.selectMasterService = ->
    log "cloudservicemodule.selectMasterService"
    serviceChoice = await user.inquireCloudServiceSelect()
    log serviceChoice
    if serviceChoice == -1 then return
    await userConfig.selectMasterCloudService(serviceChoice)
    globalScope.resetScope()
    return 

cloudservicemodule.editAnyService = ->
    log "cloudservicemodule.editAnyService"
    serviceChoice = await user.inquireCloudServiceSelect()
    log serviceChoice
    if serviceChoice == -1 then return
    await userConfig.editCloudService(serviceChoice)
    return 

cloudservicemodule.removeAnyService = ->
    log "cloudservicemodule.removeAnyService"
    serviceChoice = await user.inquireCloudServiceSelect()
    log serviceChoice
    if serviceChoice == -1 then return
    service = userConfig.getService(serviceChoice)
    globalScope.removeServiceFromScope(service)
    await userConfig.removeCloudService(serviceChoice)
    return
#endregion

cloudservicemodule.serviceAndRepoFromURL = (url) ->
    log "cloudservicemodule.serviceAndRepoFromURL"
    repoName = urlHandler.getRepo(url)
    service = getServiceObjectFromURL(url)
    return {service, repoName}

############################################################
cloudservicemodule.createRepository = (repo, visible) ->
    log "cloudservicemodule.createRepository"
    service = userConfig.getMasterService()
    await createRepository(service, repo, visible)
    globalScope.addRepoToServiceScope(repo, service)
    return

cloudservicemodule.deleteRepository = (repo) ->
    log "cloudservicemodule.deleteRepository"
    loop
        service = globalScope.serviceForRepo(repo)
        return unless service
        await deleteRepository(service, repo)
        globalScope.removeRepoFromServiceScope(repo, service)
    return

############################################################
cloudservicemodule.addDeployKey = (repoName, pubKey, title) ->
    log "cloudservicemodule.addDeployKey"
    service = globalScope.serviceForRepo(repoName)
    return unless service
    await addDeployKey(service, repoName, pubKey, title)
    return

cloudservicemodule.removeDeployKey = (repoName, title) ->
    log "cloudservicemodule.removeDeployKey"
    service = globalScope.serviceForRepo(repoName)
    return unless service
    await removeDeployKey(service, repoName, title)
    return

cloudservicemodule.addWebhook = (repoName, url, secret) ->
    log "cloudservicemodule.addWebhook"
    service = globalScope.serviceForRepo(repoName)
    return unless service
    await addWebhook(service, repoName, url, secret)
    return

cloudservicemodule.removeWebhook = (repoName, url) ->
    log "cloudservicemodule.removeWebhook"
    service = globalScope.serviceForRepo(repoName)
    return unless service
    await removeWebhook(service, repoName, url)
    return

############################################################
#region exposedInternals
cloudservicemodule.getSSHBaseForService = (service) -> sshURLBaseForService(service)
cloudservicemodule.getHTTPSBaseForService = (service) -> httpsURLBaseForService(service)
cloudservicemodule.getUserAdjustableStringProperties = getStringProperties
cloudservicemodule.allServiceTypes = allServiceTypes
cloudservicemodule.getAllServiceChoices = getAllServiceChoices
#endregion
#endregion

module.exports = cloudservicemodule