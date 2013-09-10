' other functions required for my mods
Function GetDurationString( TotalSeconds = 0 As Integer, emptyHr = 0 As Integer, emptyMin = 0 As Integer, emptySec = 0 As Integer  ) As String
   datetime = CreateObject( "roDateTime" )
   datetime.FromSeconds( TotalSeconds )
      
   hours = datetime.GetHours().ToStr()
   minutes = datetime.GetMinutes().ToStr()
   seconds = datetime.GetSeconds().ToStr()
   
   duration = ""
   If hours <> "0" or emptyHr = 1 Then
      duration = duration + hours + "h "
   End If

   If minutes <> "0" or emptyMin = 1 Then
      duration = duration + minutes + "m "
   End If
   If seconds <> "0" or emptySec = 1 Then
      duration = duration + seconds + "s"
   End If
   
   Return duration
End Function


Function RRmktime( epoch As Integer) As String
    datetime = CreateObject("roDateTime")
    datetime.FromSeconds(epoch)
    datetime.ToLocalTime()
    hours = datetime.GetHours()
    minutes = datetime.GetMinutes()
    seconds = datetime.GetSeconds()
       
    duration = ""
    hour = hours
    If hours = 0 Then
       hour = 12
    End If

    If hours > 12 Then
        hour = hours-12
    End If

    If hours >= 0 and hours < 12 Then
        AMPM = "am"
    else
        AMPM = "pm"
    End if
       
    minute = minutes.ToStr()
    If minutes < 10 Then
      minute = "0" + minutes.ToStr()
    end if

    result = hour.ToStr() + ":" + minute + AMPM

    Return result
End Function

Function RRbitrate( bitrate As Float) As String
    speed = bitrate/1000/1000
    ' brightscript doesn't have sprintf ( only include on decimal place )
    speed = speed * 10
    speed = speed + 0.5
    speed = fix(speed)
    speed = speed / 10
    format = "mbps"
    if speed < 1 then
      speed = speed*1000
      format = "kbps"
    end if
    return tostr(speed) + format
End Function

Function RRbreadcrumbDate(myscreen) As Object
    screenName = firstOf(myScreen.ScreenName, type(myScreen.Screen))
    if screenName <> invalid and screenName = "Home" then 

        myplex = GetMyPlexManager()
' ljunkie (TODO) add username in some useful place.. breadcrumbs are already to long..
'        username = ""
'        if myplex.IsSignedIn then
'            username = myplex.Username
'        end if
        Debug("update " + screenName + " screen time")
        date = CreateObject("roDateTime")
        timeString = RRmktime(date.AsSeconds())
        dateString = date.AsDateString("short-month-short-weekday")
        myscreen.Screen.SetBreadcrumbEnabled(true)
        myscreen.Screen.SetBreadcrumbText(dateString, timeString)
    else 
        Debug("will NOT update " + screenName + " screen time. " + screenName +"=Home")
    end if

End function
