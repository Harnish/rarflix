'*****************************************************************
'**  Home screen: the entry display of the application
'**
'*****************************************************************

Function createHomeScreen(viewController) As Object
    ' At the end of the day, the home screen is just a grid with a custom loader.
    ' So create a regular grid screen and override/extend as necessary.
    obj = createGridScreen(viewController, "flat-square", "stop")

    obj.Screen.SetDisplayMode("photo-fit")
    obj.Loader = createHomeScreenDataLoader(obj)

    obj.Refresh = refreshHomeScreen

    return obj
End Function

Sub refreshHomeScreen(changes)
    if type(changes) = "Boolean" and changes then
        changes = CreateObject("roAssociativeArray") ' hack for info button from grid screen (mark as watched) -- TODO later and find out why this is a Boolean
        'changes["servers"] = "true"
    end if
    ' printAny(5","1",changes) ' this prints better than printAA
    ' ljunkie Enum Changes - we could just look at changes ( but without _previous_ ) we don't know if this really changed.
    if changes.DoesExist("rf_hs_clock") and changes.DoesExist("_previous_rf_hs_clock") and changes["rf_hs_clock"] <> changes["_previous_rf_hs_clock"] then
        if changes["rf_hs_clock"] = "disabled" then
            m.Screen.SetBreadcrumbEnabled(false)
        else
            RRbreadcrumbDate(m)
        end if
    end if
    ' other rarflix changes?
    ' end ljunkie

    ' If myPlex state changed, we need to update the queue, shared sections,
    ' and any owned servers that were discovered through myPlex.
    if changes.DoesExist("myplex") then
        m.Loader.OnMyPlexChange()
    end if

    ' If a server was added or removed, we need to update the sections,
    ' channels, and channel directories.
    if changes.DoesExist("servers") then
        for each server in PlexMediaServers()
            if server.machineID <> invalid AND GetPlexMediaServer(server.machineID) = invalid then
                PutPlexMediaServer(server)
            end if
        next

        servers = changes["servers"]
        didRemove = false
        for each machineID in servers
            Debug("Server " + tostr(machineID) + " was " + tostr(servers[machineID]))
            if servers[machineID] = "removed" then
                DeletePlexMediaServer(machineID)
                didRemove = true
            else
                server = GetPlexMediaServer(machineID)
                if server <> invalid then
                    m.Loader.CreateServerRequests(server, true, false)
                end if
            end if
        next

        if didRemove then
            m.Loader.RemoveInvalidServers()
        end if
    end if

    ' Recompute our capabilities
    Capabilities(true)
End Sub

Sub ShowHelpScreen()
    header = "Welcome to Plex for Roku!"
    paragraphs = []
    paragraphs.Push("Plex for Roku automatically connects to Plex Media Servers on your local network and also works with myPlex to view queued items and connect to your published and shared servers.")
    paragraphs.Push("To download and install Plex Media Server on your computer, visit http://plexapp.com/getplex")
    paragraphs.Push("For more information on getting started, visit http://plexapp.com/roku")

    screen = createParagraphScreen(header, paragraphs, GetViewController())
    GetViewController().InitializeOtherScreen(screen, invalid)

    screen.Show()
End Sub
