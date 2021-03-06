'********************************************************************
'**  Home Media Server Application - Main
'**  Copyright (c) 2010-2013 Brian C. Lane All Rights Reserved.
'********************************************************************

'******************************************************
'** Display a scrolling grid of everything on the server
'******************************************************
Function mediaServer( url As String ) As Object
    print "url: ";url

    port=CreateObject("roMessagePort")
    grid = CreateObject("roGridScreen")
    grid.SetMessagePort(port)
    grid.SetDisplayMode("scale-to-fit")

    ' Build list of Category Names from the top level directories
    listing = getDirectoryListing(url)
    if listing = invalid then
        print "Failed to get directory listing for ";url
        return invalid
    end if
    categories = displayFiles(listing, {}, true)
    Sort(categories, function(k)
                       return LCase(k[0])
                     end function)

    ' Setup Grid with categories
    titles = CreateObject("roArray", categories.Count(), false)
    titles.Push("Search")
    for i = 0 to categories.Count()-1
        print "Category: :";categories[i][0]
        titles.Push(getLastElement(categories[i][0]))
    end for
    grid.SetupLists(titles.Count())
    grid.SetListNames(titles)

    ' Hold all the movie objects
    screen = CreateObject("roArray", categories.Count(), false)

    ' Add as utility row
    grid.SetContentList(0, getUtilRow(url))
    screen.Push(search)

    ' run the grid
    showTimeBreadcrumb(grid, true)
    grid.SetFocusedListitem(0, 1)
    grid.Show()

    loadingDialog = ShowPleaseWait("Loading Movies...", "")
    total = 0
    ' Setup each category's list
    for i = 0 to categories.Count()-1
        cat_url = url + "/" + categories[i][0]
        listing = getDirectoryListing(cat_url)
        listing_hash = CreateObject("roAssociativeArray")
        for each f in listing
            listing_hash.AddReplace(f, "")
        end for

        ' What kind of directory is this?
        dirType = directoryType(listing_hash)
        if dirType = 1 then
            displayList  = displayFiles(listing, { jpg : true })
        else if dirType = 2 then
            displayList = displayFiles(listing, { mp3 : true })
        else if dirType = 3 then
            displayList = displayFiles(listing, { mp4 : true, m4v : true, mov : true, wmv : true } )
        else if dirType = 4 then
            displayList = displayFiles(listing, { mp4 : true, m4v : true, mov : true, wmv : true } )
        end if

        total = total + displayList.Count()
        loadingDialog.SetTitle("Loading Movie #"+Stri(total))
        if dirType <> 0 then
            Sort(displayList, function(k)
                               return LCase(k[0])
                             end function)
            list = CreateObject("roArray", displayList.Count(), false)
            for j = 0 to displayList.Count()-1
                list.Push(MovieObject(displayList[j], cat_url, listing_hash))
            end for
            grid.SetContentList(1+i, list)
            screen.Push(list)
        else
            grid.SetContentList(1+i, [])
            screen.Push([])
        end if
    end for
    loadingDialog.Close()

    while true
        msg = wait(30000, port)
        if type(msg) = "roGridScreenEvent" then
            if msg.isScreenClosed() then
                return -1
            elseif msg.isListItemFocused()
                print "Focused msg: ";msg.GetMessage();"row: ";msg.GetIndex();
                print " col: ";msg.GetData()
            elseif msg.isListItemSelected()
                print "Selected msg: ";msg.GetMessage();"row: ";msg.GetIndex();
                print " col: ";msg.GetData()

                if msg.GetIndex() = 0 and msg.GetData() = 0 then
                    checkServerUrl(true)
                else if msg.GetIndex() = 0 and msg.GetData() = 1 then
                    ' search returns a roArray of MovieObjects
                    results = searchScreen(screen)

                    ' Make a new search rot
                    searchRow = getUtilRow(url)
                    searchRow.Append(results)
                    ' Remove the old one and add the new one, selecting first result
                    screen.Shift()
                    screen.Unshift(searchRow)
                    grid.SetContentList(0, searchRow)
                    grid.SetFocusedListitem(0, 2)
                else
                    playMovie(screen[msg.GetIndex()][msg.GetData()])
                end if
            endif
        else if msg = invalid then
            showTimeBreadcrumb(grid, true)
        endif
    end while
End Function


'*************************************
'** Get the utility row (Setup, Search)
'*************************************
Function getUtilRow(url As String) As Object
    ' Setup the Search/Setup entries for first row
    search = CreateObject("roArray", 2, true)
    o = CreateObject("roAssociativeArray")
    o.ContentType = "episode"
    o.Title = "Setup"
    o.SDPosterUrl = url+"/Setup-SD.png"
    o.HDPosterUrl = url+"/Setup-HD.png"
    search.Push(o)

    o = CreateObject("roAssociativeArray")
    o.ContentType = "episode"
    o.Title = "Search"
    o.SDPosterUrl = url+"/Search-SD.png"
    o.HDPosterUrl = url+"/Search-HD.png"
    search.Push(o)

    return search
End Function

'**********************************
'** Return the type of the directory
'**********************************
Function directoryType(listing_hash As Object) As Integer
    if listing_hash.DoesExist("photos") then
        return 1
    else if listing_hash.DoesExist("songs") then
        return 2
    else if listing_hash.DoesExist("episodes") then
        return 3
    else if listing_hash.DoesExist("movies") then
        return 4
    end if
    return 0
End Function


'******************************************
'** Create an object with the movie metadata
'******************************************
Function MovieObject(file As Object, url As String, listing_hash as Object) As Object
    o = CreateObject("roAssociativeArray")
    o.ContentType = "movie"
    o.ShortDescriptionLine1 = file[1]["basename"]

    ' Default images
    o.SDPosterUrl = url+"default-SD.png"
    o.HDPosterUrl = url+"default-HD.png"

    ' Search for SD & HD images and .bif files
    if listing_hash.DoesExist(file[1]["basename"]+"-SD.png") then
        o.SDPosterUrl = url+file[1]["basename"]+"-SD.png"
    else if listing_hash.DoesExist(file[1]["basename"]+"-SD.jpg") then
        o.SDPosterUrl = url+file[1]["basename"]+"-SD.jpg"
    else if listing_hash.DoesExist(file[1]["basename"]+"-HD.png") then
        o.HDPosterUrl = url+file[1]["basename"]+"-HD.png"
    else if listing_hash.DoesExist(file[1]["basename"]+"-HD.jpg") then
        o.HDPosterUrl = url+file[1]["basename"]+"-HD.jpg"
    else if listing_hash.DoesExist(file[1]["basename"]+"-SD.bif") then
        o.SDBifUrl = url+file[1]["basename"]+"-SD.bif"
    else if listing_hash.DoesExist(file[1]["basename"]+"-HD.bif") then
        o.HDBifUrl = url+file[1]["basename"]+"-HD.bif"
    else if listing_hash.DoesExist(file[1]["basename"]+".txt") then
        o.Description = getDescription(url+file[1]["basename"]+".txt")
    end if
    o.IsHD = false
    o.HDBranded = false
    o.Rating = "NR"
    o.StarRating = 100
    o.Title = file[1]["basename"]
    o.Length = 0

    ' Video related stuff (can I put this all in the same object?)
    o.StreamBitrates = [0]
    o.StreamUrls = [url + file[0]]
    o.StreamQualities = ["SD"]

    streamFormat = { mp4 : "mp4", m4v : "mp4", mov : "mp4",
                     wmv : "wmv", hls : "hls"
                   }
    if streamFormat.DoesExist(file[1]["extension"].Mid(1)) then
        o.StreamFormat = streamFormat[file[1]["extension"].Mid(1)]
    else
        o.StreamFormat = ["mp4"]
    end if

    return o
End Function

'********************************
'** Set breadcrumb to current time
'********************************
Function showTimeBreadcrumb(screen As Object, use_ampm As Boolean)
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    hour = now.GetHours()
    if use_ampm then
        if hour < 12 then
            ampm = " AM"
        else
            ampm = " PM"
            if hour > 12 then
                hour = hour - 12
            end if
        end if
    end if
    hour = tostr(hour)
    minutes = now.GetMinutes()
    if minutes < 10 then
        minutes = "0"+tostr(minutes)
    else
        minutes = tostr(minutes)
    end if
    bc = now.AsDateStringNoParam()+" "+hour+":"+minutes+ampm
    screen.SetBreadcrumbText(bc, "")
End Function

'*************************************
'** Get the last position for the movie
'*************************************
Function getLastPosition(movie As Object) As Integer
    ' use movie.Title as the filename
    lastPos = ReadAsciiFile("tmp:/"+movie.Title)
    print "Last position of ";movie.Title;" is ";lastPos
    if lastPos <> "" then
        return strtoi(lastPos)
    end if
    return 0
End Function

'******************************************************
'** Return a list of the Videos and directories
'**
'** Videos end in the following extensions
'** .mp4 .m4v .mov .wmv
'******************************************************
Function displayFiles( files As Object, fileTypes As Object, dirs=false As Boolean ) As Object
    list = []
    for each f in files
        ' This expects the path to have a system volume at the start
        p = CreateObject("roPath", "pkg:/" + f)
        if p.IsValid() and f.Left(1) <> "." then
            fileType = fileTypes[p.Split().extension.mid(1)]
            if (dirs and f.Right(1) = "/") or fileType = true then
                list.push([f, p.Split()])
            end if
        end if
    end for

    return list
End Function

'******************************************************
'** Play the video using the data from the movie
'** metadata object passed to it
'******************************************************
Sub playMovie(movie as Object)
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)
    video.SetPositionNotificationPeriod(15)

    movie.PlayStart = getLastPosition(movie)
    video.SetContent(movie)
    video.show()

    lastPos = 0
    while true
        msg = wait(0, video.GetMessagePort())
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then 'ScreenClosed event
                exit while
            else if msg.isPlaybackPosition() then
                lastPos = msg.GetIndex()
                WriteAsciiFile("tmp:/"+movie.Title, tostr(lastPos))
            else if msg.isfullresult() then
                DeleteFile("tmp:/"+movie.Title)
            else if msg.isRequestFailed() then
                print "play failed: "; msg.GetMessage()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            end if
        end if
    end while
End Sub

'******************************************************
'** Check to see if a description file (.txt) exists
'** and read it into a string.
'** And if it is missing return ""
'******************************************************
Function getDescription(url As String)
    print "Retrieving description from ";url
    http = CreateObject("roUrlTransfer")
    http.SetUrl(url)
    resp = http.GetToString()

    if resp <> invalid then
        return resp
    end if
    return ""
End Function

