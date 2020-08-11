﻿&AtClient
Var AddInId, git Export;

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	LoadEditor();
	If Not Parameters.Property("AddInURL", AddInURL) Then
		AddInTemplate = FormAttributeToValue("Object").GetTemplate("GitFor1C");
		AddInURL = PutToTempStorage(AddInTemplate, UUID);
	EndIf;
	
EndProcedure

&AtServer
Procedure LoadEditor()
	
	TempFileName = GetTempFileName();
	DeleteFiles(TempFileName);
	CreateDirectory(TempFileName);
	
	BinaryData = FormAttributeToValue("Object").GetTemplate("VAEditor");
	ZipFileReader = New ZipFileReader(BinaryData.OpenStreamForRead());
	For each ZipFileEntry In ZipFileReader.Items Do
		ZipFileReader.Extract(ZipFileEntry, TempFileName, ZIPRestoreFilePathsMode.Restore);
		BinaryData = New BinaryData(TempFileName + "/" + ZipFileEntry.FullName);
		EditorURL = GetInfoBaseURL() + "/" + PutToTempStorage(BinaryData, UUID)
			+ "&localeCode=" + Left(CurrentSystemLanguage(), 2);
	EndDo;
	DeleteFiles(TempFileName);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.MainPages.CurrentPage = Items.FolderPage;
	AddInId = "_" + StrReplace(New UUID, "-", "");
	DoAttachingAddIn(True);
	
EndProcedure

&AtClient
Procedure SetCurrentPage(Page)
	
	ClearAllItems();
	VanessaEditor().setVisible(False);
	EditableFilename = Undefined;
	Items.FormShowControl.Check = (Page = Items.StatusPage OR Page = Items.InitPage);
	Items.FormShowExplorer.Check = (Page = Items.ExplorerPage);
	Items.FormShowSearch.Check = (Page = Items.SearchPage);
	Items.MainPages.CurrentPage = Page;
	
EndProcedure

#Region Json

&AtClient
Function JsonLoad(Json) Export
	
	JSONReader = New JSONReader;
	JSONReader.SetString(Json);
	Value = ReadJSON(JSONReader);
	JSONReader.Close();
	Return Value;
	
EndFunction

&AtClient
Function JsonDump(Value) Export
	
	JSONWriter = New JSONWriter;
	JSONWriter.SetString();
	WriteJSON(JSONWriter, Value);
	Return JSONWriter.Close();
	
EndFunction

#EndRegion

&AtClient
Procedure DoAttachingAddIn(AdditionalParameters) Export
	
	NotifyDescription = New NotifyDescription("AfterAttachingAddIn", ThisForm, AdditionalParameters);
	BeginAttachingAddIn(NotifyDescription, AddInURL, AddInId, AddInType.Native);
	
EndProcedure

&AtClient
Procedure AfterAttachingAddIn(Подключение, ДополнительныеПараметры) Экспорт
	
	Если Подключение Тогда
		git = Новый("AddIn." + AddInId + ".GitFor1C");
		NotifyDescription = New NotifyDescription("AfterGettingVersion", ThisForm);
		git.BeginGettingVersion(NotifyDescription);
	ИначеЕсли ДополнительныеПараметры = Истина Тогда
		NotifyDescription = New NotifyDescription("DoAttachingAddIn", ЭтотОбъект, Ложь);
		BeginInstallAddIn(NotifyDescription, AddInURL);
	КонецЕсли;
	
EndProcedure

&AtClient
Procedure AfterGettingVersion(Value, AdditionalParameters) Экспорт
	
	Title = "GIT for 1C, version " + Value;
	AutoTitle = False;
	
EndProcedure

&AtClient
Procedure EndCallingMessage(ResultCall, ParametersCall, AdditionalParameters) Export
	
	If Not IsBlankString(ResultCall) Then
		Message(ResultCall);
	EndIf
	
EndProcedure

&AtClient
Function GitMessageNotify()
	
	Return New NotifyDescription("EndCallingMessage", ThisForm);
	
EndFunction

&AtClient
Function GitStatusNotify()
	
	Return New NotifyDescription("EndCallingStatus", ThisForm);
	
EndFunction

&AtClient
Procedure AddStatusItems(JsonData, Key, Name)
	
	Var Array;
	
	If JsonData.Property(Key, Array) Then
		ParentRow = Status.GetItems().Add();
		ParentRow.Name = Name;
		For Each Item In Array Do
			If Item.Status = "IGNORED" Then
				Continue;
			EndIf;
			Row = ParentRow.GetItems().Add();
			FillPropertyValues(Row, Item);
			Row.name = Item.new_name;
			Row.size = Item.new_size;
		EndDo;
		Items.Status.Expand(ParentRow.GetID());
		If ParentRow.GetItems().Count() = 0 Then
			Status.GetItems().Delete(ParentRow);
		EndIf
	EndIf
	
EndProcedure

&AtClient
Procedure EndCallingStatus(ResultCall, ParametersCall, AdditionalParameters) Export
	
	JsonData = JsonLoad(ResultCall);
	If JsonData.success Then
		SetCurrentPage(Items.StatusPage);
		If TypeOf(JsonData.result) = Type("Structure") Then
			AddStatusItems(JsonData.result, "Index", "Staged Changes");
			AddStatusItems(JsonData.result, "Work", "Changes");
		EndIf;
	ElsIf JsonData.error.code = 0 Then
		SetCurrentPage(Items.InitPage);
		Repository = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure RepoCommit(Command)
	
	If IsBlankString(Message) Then
		UserMessage = New UserMessage;
		UserMessage.Text = "Fill the field ""Message""";
		UserMessage.DataPath = "Message";
		UserMessage.Message();
	Else
		NotifyDescription = New NotifyDescription("EndCallingCommit", ThisForm);
		git.BeginCallingCommit(NotifyDescription, Message);
	EndIf;
	
EndProcedure

&AtClient
Procedure EndCallingCommit(ResultCall, ParametersCall, AdditionalParameters) Export
	
	JsonData = JsonLoad(ResultCall);
	If JsonData.success Then
		ClearAllItems();
		Message = Undefined;
		git.BeginCallingStatus(GitStatusNotify());
	ElsIf JsonData.error.code = 0 Then
		SetCurrentPage(Items.InitPage);
	Else
		UserMessage = New UserMessage;
		UserMessage.Text = JsonData.error.Message;
		UserMessage.Message();
	EndIf;
	
EndProcedure

&AtClient
Procedure RepoInfo(Command)
	
	git.BeginCallingInfo(GitMessageNotify(), "HEAD^{commit}");
	
EndProcedure

&AtClient
Procedure RepoHistory(Command)
	
	History.Clear();
	TextJSON = git.history();
	For Each Item In JsonLoad(TextJSON).result Do
		Row = History.Add();
		FillPropertyValues(Row, Item);
		Row.Date = ToLocalTime('19700101' + Item.time);
	EndDo;
	
EndProcedure

&AtClient
Function SelectedStatusJson()
	
	FileArray = New Array;
	For Each Id In Items.Status.SelectedRows Do
		Row = Status.FindByID(Id);
		If Not IsBlankString(Row.new_name) Then
			FileArray.Add(Row.new_name);
		EndIf;
	EndDo;
	Return JsonDump(FileArray);
	
EndFunction

&AtClient
Function GetIndexNotify()
	
	Return New NotifyDescription("EndCallingIndex", ThisForm);
	
EndFunction

&AtClient
Procedure IndexAdd(Command)
	
	AppendArray = New Array;
	RemoveArray = New Array;
	For Each Id In Items.Status.SelectedRows Do
		Row = Status.FindByID(Id);
		If Not IsBlankString(Row.new_name) Then
			If Row.status = "DELETED" Then
				RemoveArray.Add(Row.new_name);
			Else
				AppendArray.Add(Row.new_name);
			EndIf;
		EndIf;
	EndDo;
	
	git.BeginCallingAdd(GetIndexNotify(), JsonDump(AppendArray), JsonDump(RemoveArray));
	
EndProcedure

&AtClient
Procedure IndexReset(Команда)
	
	git.BeginCallingReset(GetIndexNotify(), SelectedStatusJson());
	
EndProcedure

&AtClient
Procedure IndexDiscard(Command)
	
	git.BeginCallingDiscard(GetIndexNotify(), SelectedStatusJson());
	
EndProcedure

&AtClient
Procedure EndCallingIndex(ResultCall, ParametersCall, AdditionalParameters) Export
	
	git.BeginCallingStatus(GitStatusNotify());
	
EndProcedure

&AtClient
Procedure RepoTree(Command)
	
	Tree.Clear();
	TextJSON = git.tree();
	For Each Item In JsonLoad(TextJSON).result Do
		Row = Tree.Add();
		FillPropertyValues(Row, Item);
	EndDo;
	
EndProcedure

&AtClient
Procedure RepoDiff1(Command)
	RepoDiff("INDEX", "WORK")
EndProcedure

&AtClient
Procedure RepoDiff2(Command)
	RepoDiff("HEAD", "INDEX")
EndProcedure

&AtClient
Procedure RepoDiff3(Command)
	RepoDiff("HEAD", "WORK")
EndProcedure

&AtClient
Procedure RepoDiff(s1, s2)
	
	Diff.Clear();
	TextJSON = git.diff(s1, s2);
	result = JsonLoad(TextJSON).result;
	If TypeOf(result) = Type("Array") Then
		For Each Item In result Do
			Row = Diff.Add();
			FillPropertyValues(Row, Item);
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Function ReadBlob(id)
	
	If IsBlankString(id) Then
		Return "";
	Else
		Encoding = Undefined;
		BinaryData = git.blob(id, Encoding);
		If Encoding < 0 Then
			Return "binary";
		Else
			If TypeOf(BinaryData) = Type("BinaryData") Then
				TextReader = New TextReader;
				TextReader.Open(BinaryData.OpenStreamForRead(), TextEncoding.UTF8);
				Return TextReader.Read();
			Else
				Return "";
			EndIf;
		EndIf;
	EndIf;
	
EndFunction

&AtClient
Function OpenFile(FileName)
	
	BinaryData = New BinaryData(FileName);
	NotifyDescription = New NotifyDescription("EndOpenFile", ThisForm, FileName);
	git.BeginCallingIsBinary(NotifyDescription, BinaryData);
	
EndFunction

&AtClient
Procedure EndOpenFile(ResultCall, ParametersCall, AdditionalParameters) Export
	
	BinaryData = ParametersCall[0];
	Encoding = ParametersCall[1];
	FileName = AdditionalParameters;
	
	If ResultCall = True Then
		VanessaEditor().setValue("binary", "");
		VanessaEditor().setReadOnly(True);
	Else
		TextReader = New TextReader;
		TextReader.Open(BinaryData.OpenStreamForRead(), TextEncoding.UTF8);
		VanessaEditor().setValue(TextReader.Read(), FileName);
		VanessaEditor().setReadOnly(False);
		EditableFilename = FileName;
		EditableEncoding = Encoding;
	EndIf;
	VanessaEditor().setVisible(True);
	
EndProcedure

&AtClient
Function VanessaEditor()
	
	Return Items.Editor.Document.defaultView.VanessaEditor;
	
EndFunction

&AtClient
Function VADiffEditor()
	
	Return Items.Editor.Document.defaultView.VADiffEditor;
	
EndFunction

&AtClient
Procedure EditorDocumentComplete(Item)
	
	Items.Editor.Document.defaultView.createVanessaDiffEditor("", "", "text");
	Items.Editor.Document.defaultView.createVanessaEditor("", "text").setVisible(False);
	
EndProcedure

&AtClient
Function NewFileText(Row)
	
	If IsBlankString(Row.new_id) Then
		id = git.file(Row.new_name);
	Else
		id = Row.new_id;
	EndIf;
	
	Return ReadBlob(id);
	
	
EndFunction

&AtClient
Function OldFileText(Row)
	
	If IsBlankString(Row.old_id) Then
		Return "";
	Else
		Return ReadBlob(Row.old_id);
	EndIf;
	
EndFunction

&AtClient
Procedure StatusOnActivateRow(Item)
	
	Row = Items.Status.CurrentData;
	If Row = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(Row.status) Then
		VanessaEditor().setVisible(False);
		EditableFilename = Undefined;
		Return;
	EndIf;
	
	If Row.Status = "DELETED" Then
		VanessaEditor = VanessaEditor();
		VanessaEditor.setValue(OldFileText(Row), Row.old_name);
		VanessaEditor.setVisible(True);
		VanessaEditor.setReadOnly(True);
	Else
		NewText = NewFileText(Row);
		DiffEditor = VADiffEditor();
		DiffEditor.setValue(OldFileText(Row), Row.old_name, NewText, Row.new_name);
		DiffEditor.setReadOnly(Not IsBlankString(Row.new_id) OR NewText = "binary");
		DiffEditor.setVisible(True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenBlob(Команда)
	
	Row = Items.Status.CurrentData;
	If Row = Undefined Then
		Return;
	ElsIf Row.Status = "DELETED" Then
		NotifyDescription = New NotifyDescription("EndOpenBlob", ThisForm, Row.old_name);
		git.BeginCallingBlob(NotifyDescription, Row.old_id);
	ElsIf Not IsBlankString(Row.new_id) Then
		NotifyDescription = New NotifyDescription("EndOpenBlob", ThisForm, Row.new_name);
		git.BeginCallingBlob(NotifyDescription, Row.new_id);
	Else
		OpenFile(Repository + Row.new_name);
	EndIf;
	
EndProcedure

&AtClient
Procedure EndOpenBlob(ResultCall, ParametersCall, AdditionalParameters) Export
	
	BinaryData = ResultCall;
	Encoding = ParametersCall[1];
	FileName = AdditionalParameters;
	
	If Encoding < 0 Then
		VanessaEditor().setValue("binary", "");
	Else
		TextReader = New TextReader;
		TextReader.Open(BinaryData.OpenStreamForRead(), TextEncoding.UTF8);
		VanessaEditor().setValue(TextReader.Read(), FileName);
	EndIf;
	VanessaEditor().setReadOnly(True);
	VanessaEditor().setVisible(True);
	
EndProcedure

&AtClient
Function GetFormName(Name)
	
	Names = StrSplit(FormName, ".");
	Names[Names.Count() - 1] = Name;
	Return StrConcat(Names, ".");
	
EndFunction

&AtClient
Procedure AutoTest(Command)
	
	NewName = GetFormName("Test");
	NewParams = New Structure("AddInId", AddInId);
	TestForm = GetForm(NewName, NewParams, ThisForm, New Uuid);
	TestForm.Test(AddInId);
	
EndProcedure

&AtClient
Procedure OpenFolder(Command)
	
	NotifyDescription = New NotifyDescription("OpenFolderEnd", ThisForm);
	FileDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	FileDialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure OpenFolderEnd(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles <> Undefined Then
		VanessaEditor().setVisible(False);
		EditableFilename = Undefined;
		File = New File(SelectedFiles[0]);
		Title = File.Name;
		AutoTitle = True;
		Directory = File.FullName;
		NotifyDescription = New NotifyDescription("FindFolderEnd", ThisForm, File.FullName);
		git.BeginCallingFind(NotifyDescription, SelectedFiles[0]);
	EndIf;
	
EndProcedure

&AtClient
Procedure FindFolderEnd(ResultCall, ParametersCall, AdditionalParameters) Export
	
	JsonData = JsonLoad(ResultCall);
	If JsonData.Success Then
		File = New File(JsonData.result);
		Repository = File.Path;
		NotifyDescription = New NotifyDescription("OpenRepositoryEnd", ThisForm);
		git.BeginCallingOpen(NotifyDescription, JsonData.Result);
	Else
		SetCurrentPage(Items.InitPage);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenRepositoryEnd(ResultCall, ParametersCall, AdditionalParameters) Export
	
	JsonData = JsonLoad(ResultCall);
	If JsonData.Success Then
		git.BeginCallingStatus(GitStatusNotify());
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseFolder(Command)
	
	git.BeginCallingClose(New NotifyDescription);
	SetCurrentPage(Items.FolderPage);
	Repository = Undefined;
	Directory = Undefined;
	Title = Undefined;
	
EndProcedure

&AtClient
Procedure RefreshStatus(Command)
	
	git.BeginCallingStatus(GitStatusNotify());
	
EndProcedure

&AtClient
Procedure CloneRepository(Command)
	
	OpenForm(GetFormName("Clone"), , ThisForm, New Uuid);
	
EndProcedure

&AtClient
Procedure InitializeRepo(Command)
	
	NotifyDescription = New NotifyDescription("OpenRepositoryEnd", ThisForm);
	git.BeginCallingInit(NotifyDescription, Directory);
	
EndProcedure

&AtClient
Procedure ClearAllItems()
	
	Files.GetItems().Clear();
	Status.GetItems().Clear();
	Explorer.GetItems().Clear();
	VanessaEditor().setVisible(False);
	EditableFilename = Undefined;
	
EndProcedure

&AtClient
Procedure ShowExplorer(Command)
	
	If Not IsBlankString(Directory) Then
		SetCurrentPage(Items.ExplorerPage);
		FillExplorerItems(Explorer.GetItems(), Directory);
		CurrentItem = Items.Explorer;
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowSearch(Command)
	
	If Not IsBlankString(Directory) Then
		SetCurrentPage(Items.SearchPage);
		CurrentItem = Items.SearchText;
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowControl(Command)
	
	If Not IsBlankString(Directory) Then
		SetCurrentPage(Items.StatusPage);
		git.BeginCallingStatus(GitStatusNotify());
		CurrentItem = Items.Status;
	EndIf;
	
EndProcedure

&AtClient
Procedure FillExplorerItems(Items, Directory, Parent = Undefined)
	
	AdditionalParameters = New Structure("Items, Parent", Items, Parent);
	NotifyDescription = New NotifyDescription("EndFindingFiles", ThisForm, AdditionalParameters);
	BeginFindingFiles(NotifyDescription, Directory, "*.*", False);
	
EndProcedure

&AtClient
Procedure EndFindingFiles(FilesFound, AdditionalParameters) Export
	
	ParentNode = AdditionalParameters.Parent;
	ParentItems = AdditionalParameters.Items;
	
	ParentItems.Clear();
	OnlyFiles = New Array;
	For Each File In FilesFound Do
		If (File.IsDirectory()) Then
			If File.Name = ".git" Then
				Continue;
			EndIf;
			Row = ParentItems.Add();
			Row.IsDirectory = True;
			FillPropertyValues(Row, File);
			Row.GetItems().Add();
		Else
			OnlyFiles.Add(File);
		EndIf;
	EndDo;
	
	For Each File In OnlyFiles Do
		FillPropertyValues(ParentItems.Add(), File);
	EndDo;
	
	If ParentNode <> Undefined Then
		If ParentItems.Count() = 0 Then
			Items.Explorer.Collapse(ParentNode.GetId());
			ParentItems.Add();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExplorerBeforeExpand(Item, Row, Cancel)
	
	ParentRow = Explorer.FindByID(Row);
	If ParentRow <> Undefined Then
		FillExplorerItems(ParentRow.GetItems(), ParentRow.Fullname, ParentRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExplorerOnActivateRow(Item)
	
	AttachIdleHandler("ExplorerReadFile", 0.1, True);
	
EndProcedure

&AtClient
Procedure ExplorerReadFile() Export
	
	Data = Items.Explorer.CurrentData;
	If Data <> Undefined Then
		If Data.IsDirectory Then
			VanessaEditor().setVisible(False);
			EditableFilename = Undefined;
		Else
			OpenFile(Data.fullname);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SearchTextOnChange(Item)
	
	Files.GetItems().Clear();
	If Not IsBlankString(SearchText) Then
		NotifyDescription = New NotifyDescription("EndSearchText", ThisForm);
		git.BeginCallingFindFiles(NotifyDescription, Directory, "*.*", SearchText, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure EndSearchText(ResultCall, ParametersCall, AdditionalParameters) Export
	
	Files.GetItems().Clear();
	JsonData = JsonLoad(ResultCall);
	If TypeOf(JsonData) = Type("Array") Then
		For Each Item In JsonData Do
			Row = Files.GetItems().Add();
			FillPropertyValues(Row, Item);
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure FilesOnActivateRow(Item)
	
	AttachIdleHandler("SearchReadFile", 0.1, True);
	
EndProcedure

&AtClient
Procedure SearchReadFile() Export
	
	Data = Items.Files.CurrentData;
	If Data <> Undefined Then
		OpenFile(Data.path);
	EndIf;
	
EndProcedure

&AtClient
Procedure Signature(Command)

	OpenForm(GetFormName("Sign"), , ThisForm, New Uuid);
	
EndProcedure
