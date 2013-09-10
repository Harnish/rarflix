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
        username = ""
        if myplex.IsSignedIn then
            username = myplex.Username
        end if
        Debug("update " + screenName + " screen time")
        date = CreateObject("roDateTime")
        timeString = RRmktime(date.AsSeconds())
        dateString = date.AsDateString("short-month-short-weekday")
        myscreen.Screen.SetBreadcrumbEnabled(true)
'        myscreen.Screen.SetBreadcrumbText(username+" " dateString, timeString)
        myscreen.Screen.SetBreadcrumbText(username, timeString)
    else 
        Debug("will NOT update " + screenName + " screen time. " + screenName +"=Home")
    end if

End function



Function GetAllMyPlexUsers() as Object
    info = CreateObject("roAssociativeArray")
    l = CreateObject("roList")
    for i = 1 to 99 step 1
       check = "AuthToken" + tostr(i)
       otherToken = RegRead(check, "myplex")
       if otherToken <> invalid then 
           obj = CreateObject("roAssociativeArray")
           obj.CreateRequest = mpCreateRequest
           obj.ValidateToken = mpValidateToken
           obj.Disconnect = mpDisconnect

           obj.ExtraHeaders = {}
           obj.ExtraHeaders["X-Plex-Provides"] = "player"
           ' Masquerade as a basic Plex Media Server
           obj.serverUrl = "https://my.plexapp.com"
           obj.name = "myPlex"

           req = CreateObject("roAssociativeArray")
           req = obj.CreateRequest("", "/users/sign_in.xml", false)
           port = CreateObject("roMessagePort")
           req.SetPort(port)
           req.AsyncPostFromString("auth_token=" + otherToken)
           event = wait(10000, port)
           ' TODO ( add to regkey and update periodically ) or just make users exit to get an update
           ' this lookup on teh prefs screen is pretty slow every time
           if type(event) = "roUrlEvent" AND event.GetInt() = 1 AND event.GetResponseCode() = 201 then
               xml = CreateObject("roXMLElement")
               xml.Parse(event.GetString())
               obj1 = CreateObject("roAssociativeArray")
               obj1.num = i
               obj1.regkey = check 'AuthToken#
               obj1.username = xml@username
               obj1.email = xml@email
               obj1.token = otherToken
               l.AddTail(obj1)
               Debug("Validated myPlex " + check + " token, corresponds to " + xml@username)
           else
               Debug("Failed to get TokenDetails for myPlex token" + check)
           end if
       end if
    end for
 ' print l.Count();" entries"
 ' l.ResetIndex()
 ' for each li in l
 '     printAA(li)
 '     print li.username, li.email, li.token
 ' end for
 'stop
 return l
End Function

function showPinScreen(pin = "pin" as string) as boolean 
 if pin <> "pin" then
    pin = "pin_" + pin
 end if

 wanted = RegRead(pin, "authentication")
 result = false

 ' confirm pin code
 if wanted <> invalid then 
     Debug("checking pin for pin key for " + pin)
     screen = CreateObject("roPinEntryDialog")
     screen.setTitle("Confirm your identity")
     screen.addButton(1,"Next")
     screen.addButton(0,"Cancel")
     screen.SetNumPinEntryFields(4)
     port= CreateObject("roMessagePort")
     screen.setMessagePort(port)
     screen.show()
     while true
        msg=wait(0, screen.GetMessagePort())
        if(msg.getIndex()=1)
            if(screen.pin()=regRead(pin, "authentication"))
  	        result = true
                exit while
            else
                screen.close()
               exit while
            end if
        end if

        if(msg.getIndex()=0)
           exit while
        end if
     end while
 else
     'pin not set - so lets set one
     Debug("PIN NOT set for yet, let's create one " + pin)
     screen = CreateObject("roPinEntryDialog")
     screen.setTitle("Set PIN code")
     screen.addButton(1,"Next")
     screen.addButton(0,"Cancel")
     screen.SetNumPinEntryFields(4)
     port= CreateObject("roMessagePort")
     screen.setMessagePort(port)
     screen.show()
     while true
        msg=wait(0, screen.GetMessagePort())
        if(msg.getIndex()=1)
            print "setting PIN" + pin + " to " + screen.pin()
            RegWrite(pin, screen.pin(), "authentication")
	    result = true
            exit while
        else
            exit while
       end if
  
       if(msg.getIndex()=0)
           exit while
       end if
     end while
 end if

 screen.close()
 return result   

end function


sub ResetSelToken() 
    token_cur = RegRead("AuthToken", "myplex")
    for i = 1 to 99 step 1
       check = "AuthToken" + tostr(i)
       otherToken = RegRead(check, "myplex")
       if otherToken = token_cur then 
        print "ResetSelToken called: resetting token back to " + check
          RegWrite("switchaccounts", check, "preferences")
       end if
     end for
end sub