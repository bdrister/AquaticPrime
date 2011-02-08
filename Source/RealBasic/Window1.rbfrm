#tag Window
Begin Window Window1
   BackColor       =   16777215
   Backdrop        =   ""
   CloseButton     =   True
   Composite       =   False
   Frame           =   0
   FullScreen      =   False
   HasBackColor    =   False
   Height          =   400
   ImplicitInstance=   True
   LiveResize      =   True
   MacProcID       =   0
   MaxHeight       =   32000
   MaximizeButton  =   True
   MaxWidth        =   32000
   MenuBar         =   1107226425
   MenuBarVisible  =   True
   MinHeight       =   400
   MinimizeButton  =   True
   MinWidth        =   600
   Placement       =   3
   Resizeable      =   True
   Title           =   "Drag license over this window"
   Visible         =   True
   Width           =   600
   Begin StaticText StaticText2
      AutoDeactivate  =   True
      Bold            =   ""
      DataField       =   ""
      DataSource      =   ""
      Enabled         =   True
      Height          =   20
      HelpTag         =   ""
      Index           =   -2147483648
      InitialParent   =   ""
      Italic          =   ""
      Left            =   0
      LockBottom      =   ""
      LockedInPosition=   False
      LockLeft        =   True
      LockRight       =   True
      LockTop         =   True
      Multiline       =   ""
      Scope           =   0
      TabIndex        =   2
      TabPanelIndex   =   0
      Text            =   ""
      TextAlign       =   1
      TextColor       =   0
      TextFont        =   "SmallSystem"
      TextSize        =   0
      TextUnit        =   0
      Top             =   140
      Underline       =   ""
      Visible         =   True
      Width           =   600
   End
   Begin StaticText StaticText1
      AutoDeactivate  =   True
      Bold            =   ""
      DataField       =   ""
      DataSource      =   ""
      Enabled         =   True
      Height          =   242
      HelpTag         =   ""
      Index           =   -2147483648
      InitialParent   =   ""
      Italic          =   ""
      Left            =   14
      LockBottom      =   True
      LockedInPosition=   False
      LockLeft        =   True
      LockRight       =   True
      LockTop         =   True
      Multiline       =   ""
      Scope           =   0
      TabIndex        =   1
      TabPanelIndex   =   0
      Text            =   "Drag license over this window"
      TextAlign       =   1
      TextColor       =   0
      TextFont        =   "System"
      TextSize        =   0
      TextUnit        =   0
      Top             =   138
      Underline       =   ""
      Visible         =   True
      Width           =   572
      Begin Listbox Listbox1
         AutoDeactivate  =   True
         AutoHideScrollbars=   True
         Bold            =   ""
         Border          =   True
         ColumnCount     =   2
         ColumnsResizable=   ""
         ColumnWidths    =   ""
         DataField       =   ""
         DataSource      =   ""
         DefaultRowHeight=   20
         Enabled         =   True
         EnableDrag      =   ""
         EnableDragReorder=   ""
         GridLinesHorizontal=   0
         GridLinesVertical=   0
         HasHeading      =   True
         HeadingIndex    =   -1
         Height          =   211
         HelpTag         =   ""
         Hierarchical    =   ""
         Index           =   -2147483648
         InitialParent   =   "StaticText1"
         InitialValue    =   "Key	Value"
         Italic          =   ""
         Left            =   20
         LockBottom      =   True
         LockedInPosition=   False
         LockLeft        =   True
         LockRight       =   True
         LockTop         =   True
         RequiresSelection=   ""
         Scope           =   0
         ScrollbarHorizontal=   ""
         ScrollBarVertical=   True
         SelectionType   =   0
         TabIndex        =   0
         TabPanelIndex   =   0
         TabStop         =   True
         TextFont        =   "System"
         TextSize        =   0
         TextUnit        =   0
         Top             =   169
         Underline       =   ""
         UseFocusRing    =   True
         Visible         =   False
         Width           =   560
         _ScrollWidth    =   -1
      End
   End
   Begin TextArea TextArea1
      AcceptTabs      =   ""
      Alignment       =   0
      AutoDeactivate  =   True
      BackColor       =   16777215
      Bold            =   ""
      Border          =   True
      DataField       =   ""
      DataSource      =   ""
      Enabled         =   True
      Format          =   ""
      Height          =   87
      HelpTag         =   ""
      HideSelection   =   True
      Index           =   -2147483648
      Italic          =   ""
      Left            =   20
      LimitText       =   0
      LockBottom      =   ""
      LockedInPosition=   False
      LockLeft        =   True
      LockRight       =   True
      LockTop         =   True
      Mask            =   ""
      Multiline       =   True
      ReadOnly        =   ""
      Scope           =   0
      ScrollbarHorizontal=   ""
      ScrollbarVertical=   False
      Styled          =   True
      TabIndex        =   3
      TabPanelIndex   =   0
      TabStop         =   True
      Text            =   ""
      TextColor       =   0
      TextFont        =   "System"
      TextSize        =   0
      TextUnit        =   0
      Top             =   39
      Underline       =   ""
      UseFocusRing    =   True
      Visible         =   True
      Width           =   560
   End
   Begin StaticText StaticText3
      AutoDeactivate  =   True
      Bold            =   ""
      DataField       =   ""
      DataSource      =   ""
      Enabled         =   True
      Height          =   20
      HelpTag         =   ""
      Index           =   -2147483648
      InitialParent   =   ""
      Italic          =   ""
      Left            =   20
      LockBottom      =   ""
      LockedInPosition=   False
      LockLeft        =   True
      LockRight       =   True
      LockTop         =   True
      Multiline       =   ""
      Scope           =   0
      TabIndex        =   4
      TabPanelIndex   =   0
      Text            =   "Public key (drag or paste hex)"
      TextAlign       =   0
      TextColor       =   0
      TextFont        =   "System"
      TextSize        =   0
      TextUnit        =   0
      Top             =   14
      Underline       =   ""
      Visible         =   True
      Width           =   275
   End
End
#tag EndWindow

#tag WindowCode
	#tag Event
		Sub DropObject(obj As DragItem, action As Integer)
		  
		  if obj.folderItemAvailable then
		    CheckLicense obj.folderItem
		  end if
		End Sub
	#tag EndEvent

	#tag Event
		Sub Open()
		  
		  anyFileType = new FileType
		  anyFileType.Name = "special/any"
		  anyFileType.MacType = "????"
		  anyFileType.Extensions = ""
		  
		  self.acceptFileDrop anyFileType
		  
		  app.autoQuit = true
		  
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0
		Sub CheckLicense(licenseFile as folderItem)
		  
		  licenseValidator = new AquaticPrime(TextArea1.text)
		  
		  if licenseValidator.LastError <> "" then
		    
		    beep
		    Listbox1.visible = false
		    StaticText2.visible = false
		    staticText1.text = "Error: "+licenseValidator.LastError
		    staticText1.visible = true
		    
		  else
		    
		    dim licenseDict as dictionary = licenseValidator.DictionaryForLicenseFile(licenseFile)
		    
		    if licenseDict = nil then
		      beep
		      Listbox1.visible = false
		      StaticText2.visible = false
		      staticText1.text = "License is NOT VALID: "+licenseValidator.LastError
		      staticText1.visible = true
		    else
		      Listbox1.deleteAllRows
		      StaticText2.text = ""
		      for i as integer = 0 to licenseDict.count-1
		        Listbox1.addRow licenseDict.key(i)
		        Listbox1.cell(listbox1.lastIndex, 1) = licenseDict.value(licenseDict.key(i))
		      next
		      StaticText2.text = "License Hash: "+licenseValidator.hash
		      staticText1.visible = false
		      staticText2.visible = true
		      listbox1.visible = true
		    end if
		    
		  end if
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		anyFileType As FileType
	#tag EndProperty

	#tag Property, Flags = &h0
		licenseValidator As AquaticPrime
	#tag EndProperty


#tag EndWindowCode

#tag Events Listbox1
	#tag Event
		Sub Open()
		  
		  me.parent = nil
		  me.columnAlignment(0) = Listbox.alignCenter
		  me.columnAlignment(1) = Listbox.alignCenter
		End Sub
	#tag EndEvent
#tag EndEvents
