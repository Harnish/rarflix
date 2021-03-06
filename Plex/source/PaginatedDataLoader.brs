'*
'* Loads data for multiple keys one page at a time. Useful for things
'* like the grid screen that want to load additional data in the background.
'*

Function createPaginatedLoader(container, initialLoadSize, pageSize, item = invalid as dynamic)
    loader = CreateObject("roAssociativeArray")
    initDataLoader(loader)

    loader.server = container.server
    loader.sourceUrl = container.sourceUrl
    loader.names = container.GetNames()
    loader.initialLoadSize = initialLoadSize
    loader.pageSize = pageSize

    loader.contentArray = []

    keys = container.GetKeys()

    ' Hide Rows - ljunkie ( remove key and loader.names )
    if type(item) = "roAssociativeArray" and item.contenttype = "section" then 
        itype = item.type
        for index = 0 to keys.Count() - 1
            if keys[index] <> invalid then  ' delete from underneath does this
                hide = false
                rf_hide_key = "rf_hide_" + keys[index]

                ' recenltyAdded and newest(recently Release/Aired) are special/hidden per type
                if keys[index] = "recentlyAdded" or keys[index] = "newest" and (itype = "movie" or itype = "show" or itype = "artist") then 
                    rf_hide_key = rf_hide_key + "_" + itype 'print "Checking " + keys[index] + " for specific type of hide: " + itype
                end if

                if RegRead(rf_hide_key, "preferences", "show") <> "show"  then 
                    Debug("---- ROW HIDDEN: " + keys[index] + " - hide specified via reg " + rf_hide_key )
                    keys.Delete(index)
                    loader.names.Delete(index)
                    index = index - 1
                end if
            end if
        end for
    end if
    ' End Hide Rows

    ' ljunkie - CUSTOM new rows (movies only for now) -- allow new rows based on allows PLEX filters
    if type(item) = "roAssociativeArray" and item.contenttype = "section" and item.type = "movie" then 
        size_limit = RegRead("rf_rowfilter_limit", "preferences","200") 'gobal size limit Toggle for filter rows

        ' unwatched recently released
        new_key = "all?type=1&unwatched=1&sort=originallyAvailableAt:desc"
        if RegRead("rf_hide_"+new_key, "preferences", "show") = "show" then 
            new_key = new_key + "&X-Plex-Container-Start=0&X-Plex-Container-Size=" + size_limit
            keys.Push(new_key)
            loader.names.Push("Recently Released (unwatched)")
        end if

        ' unwatched recently Added
        new_key = "all?type=1&unwatched=1&sort=addedAt:desc"
        if RegRead("rf_hide_"+new_key, "preferences", "show") = "show" then 
            new_key = new_key + "&X-Plex-Container-Start=0&X-Plex-Container-Size=" + size_limit
            keys.Push(new_key)
            loader.names.Push("Recently Added (unwatched)")
        end if
    end if
    ' END custom rows

    for index = 0 to keys.Count() - 1
        status = CreateObject("roAssociativeArray")
        status.content = []
        status.loadStatus = 0 ' 0:Not loaded, 1:Partially loaded, 2:Fully loaded
        status.key = keys[index]
        status.name = loader.names[index]
        status.pendingRequests = 0
        status.countLoaded = 0

        loader.contentArray[index] = status
    end for

    ' Set up search nodes as the last row if we have any
    if RegRead("rf_hide_search", "preferences", "show") = "show" then     ' ljunkie - or hide it ( why would someone do this? but here is the option...)
        searchItems = container.GetSearch()
        if searchItems.Count() > 0 then
            status = CreateObject("roAssociativeArray")
            status.content = searchItems
            status.loadStatus = 0
            status.key = "_search_"
            status.name = "Search"
            status.pendingRequests = 0
            status.countLoaded = 0
    
            loader.contentArray.Push(status)
        end if
    end if

    ' Reorder container sections so that frequently accessed sections
    ' are displayed first. Make sure to revert the search row's dummy key
    ' to invalid so we don't try to load it.
    ReorderItemsByKeyPriority(loader.contentArray, RegRead("section_row_order", "preferences", ""))
    for index = 0 to loader.contentArray.Count() - 1
        status = loader.contentArray[index]
        loader.names[index] = status.name
         if status.key = "_search_" then
            status.key = invalid
        end if
    next

    loader.LoadMoreContent = loaderLoadMoreContent
    loader.GetLoadStatus = loaderGetLoadStatus
    loader.RefreshData = loaderRefreshData
    loader.StartRequest = loaderStartRequest
    loader.OnUrlEvent = loaderOnUrlEvent
    loader.GetPendingRequestCount = loaderGetPendingRequestCount

    ' When we know the full size of a container, we'll populate an array with
    ' dummy items so that the counts show up correctly on grid screens. It
    ' should generally provide a smoother loading experience. This is the
    ' metadata that will be used for pending items.
    loader.LoadingItem = {
        title: "Loading..."
    }

    return loader
End Function

'*
'* Load more data either in the currently focused row or the next one that
'* hasn't been fully loaded. The return value indicates whether subsequent
'* rows are already loaded.
'*
Function loaderLoadMoreContent(focusedIndex, extraRows=0)
    status = invalid
    extraRowsAlreadyLoaded = true
    for i = 0 to extraRows
        index = focusedIndex + i
        if index >= m.contentArray.Count() then
            exit for
        else if m.contentArray[index].loadStatus < 2 AND m.contentArray[index].pendingRequests = 0 then
            if status = invalid then
                status = m.contentArray[index]
                loadingRow = index
            else
                extraRowsAlreadyLoaded = false
                exit for
            end if
        end if
    end for

    if status = invalid then return true

    ' Special case, if this is a row with static content, update the status
    ' and tell the listener about the content.
    if status.key = invalid then
        status.loadStatus = 2
        if m.Listener <> invalid then
            m.Listener.OnDataLoaded(loadingRow, status.content, 0, status.content.Count(), true)
        end if
        return extraRowsAlreadyLoaded
    end if

    startItem = status.countLoaded
    if startItem = 0 then
        count = m.initialLoadSize
    else
        count = m.pageSize
    end if

    status.loadStatus = 1
    m.StartRequest(loadingRow, startItem, count)

    return extraRowsAlreadyLoaded
End Function

Sub loaderRefreshData()
    for row = 0 to m.contentArray.Count() - 1
        status = m.contentArray[row]
        if status.key <> invalid AND status.loadStatus <> 0 then
            m.StartRequest(row, 0, m.pageSize)
        end if
    next
End Sub

Sub loaderStartRequest(row, startItem, count)
    status = m.contentArray[row]
    request = CreateObject("roAssociativeArray")
    ' REM ljunkie - need to add more rows? wrong section - but this section could override a row (might be useful if we can get toggles working)
    ' if status.key = "recentlyAdded" then
    '     status.key = "all?type=1&unwatched=1&sort=addedAt:desc"
    ' end if
    '
    ' if status.key = "newest" then
    '     status.key = "all?type=1&unwatched=1&sort=originallyAvailableAt:desc"
    ' end if
    ' print "start request ---------------------- " + status.key

    httpRequest = m.server.CreateRequest(m.sourceUrl, status.key)
    httpRequest.AddHeader("X-Plex-Container-Start", startItem.tostr())
    httpRequest.AddHeader("X-Plex-Container-Size", count.tostr())
    request.row = row

    ' Associate the request with our listener's screen ID, so that any pending
    ' requests are canceled when the screen is popped.
    m.ScreenID = m.Listener.ScreenID

    if GetViewController().StartRequest(httpRequest, m, request) then
        status.pendingRequests = status.pendingRequests + 1
    else
        Debug("Failed to start request for row " + tostr(row) + ": " + tostr(httpRequest.GetUrl()))
    end if
End Sub

Sub loaderOnUrlEvent(msg, requestContext)
    status = m.contentArray[requestContext.row]
    status.pendingRequests = status.pendingRequests - 1

    url = requestContext.Request.GetUrl()

    if msg.GetResponseCode() <> 200 then
        Debug("Got a " + tostr(msg.GetResponseCode()) + " response from " + tostr(url) + " - " + tostr(msg.GetFailureReason()))
        return
    end if

    xml = CreateObject("roXMLElement")
    xml.Parse(msg.GetString())

    response = CreateObject("roAssociativeArray")
    response.xml = xml
    response.server = m.server
    response.sourceUrl = url
    container = createPlexContainerForXml(response)

    ' If the container doesn't play nice with pagination requests then
    ' whatever we got is the total size.
    if response.xml@totalSize <> invalid then
        totalSize = strtoi(response.xml@totalSize)
    else
        totalSize = container.Count()
    end if

    ' ljunkie - hack to limit the unwatched rows ( we can remove this if Plex ever gives us Unwatched Recently Added/Released Directories )
    ' INFO: Normally Plex will continue to load data when the "loaded content size" < "XML MediaContainer totalSize" ( status.countLoaded < totalSize )
    ' Since we are specifying the Container-Size - we will never be able to load the totalSize; reset the totalSize to "MediaContainer Size"
    r = CreateObject("roRegex", "all\?.*X-Plex-Container-Size\=", "i")
    if r.IsMatch(container.sourceurl) then
        totalSize = container.Count()
        Debug("----------- " + container.sourceurl)
        Debug("----------- RF force container (stop loading) after X-Plex-Container-Size=" + tostr(totalSize))
    end if
    ' end hack

    if totalSize <= 0 then
        status.loadStatus = 2
        startItem = 0
        countLoaded = status.content.Count()
        status.countLoaded = countLoaded
    else
        startItem = firstOf(response.xml@offset, msg.GetResponseHeaders()["X-Plex-Container-Start"], "0").toInt()

        countLoaded = container.Count()

        if startItem <> status.content.Count() then
            Debug("Received paginated response for index " + tostr(startItem) + " of list with length " + tostr(status.content.Count()))
            metadata = container.GetMetadata()
            for i = 0 to countLoaded - 1
                status.content[startItem + i] = metadata[i]
            next
        else
            status.content.Append(container.GetMetadata())
        end if

        if totalSize > status.content.Count() then
            ' We could easily fill the entire array with our dummy loading item,
            ' but it's usually just wasted cycles at a time when we care about
            ' the app feeling responsive. So make the first and last item use
            ' our dummy metadata and everything in between will be blank.
            status.content.Push(m.LoadingItem)
            status.content[totalSize - 1] = m.LoadingItem
        end if

        if status.loadStatus <> 2 then
            status.countLoaded = startItem + countLoaded
        end if

        Debug("Count loaded is now " + tostr(status.countLoaded) + " out of " + tostr(totalSize))

        if status.loadStatus = 2 AND startItem + countLoaded < totalSize then
            ' We're in the middle of refreshing the row, kick off the
            ' next request.
            m.StartRequest(requestContext.row, startItem + countLoaded, m.pageSize)
        else if status.countLoaded < totalSize then
            status.loadStatus = 1
        else
            status.loadStatus = 2
        end if
    end if

    while status.content.Count() > totalSize
        status.content.Pop()
    end while

    if countLoaded > status.content.Count() then
        countLoaded = status.content.Count()
    end if

    if status.countLoaded > status.content.Count() then
        status.countLoaded = status.content.Count()
    end if

    if m.Listener <> invalid then
        m.Listener.OnDataLoaded(requestContext.row, status.content, startItem, countLoaded, status.loadStatus = 2)
    end if
End Sub

Function loaderGetLoadStatus(row)
    return m.contentArray[row].loadStatus
End Function

Function loaderGetPendingRequestCount() As Integer
    pendingRequests = 0
    for each status in m.contentArray
        pendingRequests = pendingRequests + status.pendingRequests
    end for

    return pendingRequests
End Function
