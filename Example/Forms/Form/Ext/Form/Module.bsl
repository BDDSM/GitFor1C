﻿&AtClient
Var AddInId, git Export;

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	LoadEditor();
	If Not Parameters.Property("AddInURL", AddInURL) Then
		AddInTemplate = FormAttributeToValue("Object").GetTemplate("GitFor1C");
		AddInURL = PutToTempStorage(AddInTemplate, UUID);
	EndIf;
	Message = "Init commit";
	
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
Процедура AfterGettingVersion(Значение, ДополнительныеПараметры) Экспорт
	
	Заголовок = "GIT для 1C, версия " + Значение;
	
КонецПроцедуры

&AtClient
Функция ПрочитатьСтрокуJSON(ТекстJSON)
	
	Если ПустаяСтрока(ТекстJSON) Тогда
		Возврат Неопределено;
	КонецЕсли;
	
	ЧтениеJSON = Новый ЧтениеJSON();
	ЧтениеJSON.УстановитьСтроку(ТекстJSON);
	Возврат ПрочитатьJSON(ЧтениеJSON);
	
КонецФункции

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
Procedure SetStatus(TextJson) Export
	
	Status.GetItems().Clear();
	VanessaEditor().setVisible(False);
	JsonData = JsonLoad(TextJson);
	If JsonData.success Then
		Items.MainPages.CurrentPage = Items.StatusPage;
		If TypeOf(JsonData.result) = Type("Structure") Then
			AddStatusItems(JsonData.result, "Index", "Staged Changes");
			AddStatusItems(JsonData.result, "Work", "Changes");
		EndIf;
	ElsIf JsonData.error.code = 0 Then
		Items.MainPages.CurrentPage = Items.InitializePage;
	EndIf;
	
EndProcedure

&AtClient
Procedure EndCallingStatus(ResultCall, ParametersCall, AdditionalParameters) Export
	
	SetStatus(ResultCall);
	
EndProcedure

&AtClient
Procedure RepoCommit(Command)
	
	git.BeginCallingCommit(GitMessageNotify(), Message);
	
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
	Items.FormPages.CurrentPage = Items.PageHistory;
	
EndProcedure

&AtClient
Procedure IndexAdd(Command)
	
	For Each Id In Items.Status.SelectedRows Do
		Row = Status.FindByID(Id);
		git.add(Row.name);
	EndDo;
	git.BeginCallingStatus(GitStatusNotify());
	
EndProcedure

&НаКлиенте
Процедура IndexReset(Команда)
	
	For Each Id In Items.Status.SelectedRows Do
		Row = Status.FindByID(Id);
		git.reset(Row.name);
	EndDo;
	git.BeginCallingStatus(GitStatusNotify());
	
КонецПроцедуры

&AtClient
Procedure IndexRemove(Command)
	
	For Each Id In Items.Status.SelectedRows Do
		Row = Status.FindByID(Id);
		git.remove(Row.name);
	EndDo;
	git.BeginCallingStatus(GitStatusNotify());
	
EndProcedure

&AtClient
Procedure IndexDiscard(Command)

	For Each Id In Items.Status.SelectedRows Do
		Row = Status.FindByID(Id);
		git.discard(Row.name);
	EndDo;
	git.BeginCallingStatus(GitStatusNotify());
	
EndProcedure

&AtClient
Procedure GetDefaultSignature(Command)
	
	signature = JsonLoad(git.signature);
	Name = signature.result.name;
	Email = signature.result.email;
	
EndProcedure

&AtClient
Procedure SetSignatureAuthor(Command)
	
	git.setAuthor(Name, Email);
	
EndProcedure

&AtClient
Procedure SetSignatureCommitter(Command)
	
	git.setCommitter(Name, Email);
	
EndProcedure

&AtClient
Procedure RepoTree(Command)
	
	Tree.Clear();
	TextJSON = git.tree();
	For Each Item In JsonLoad(TextJSON).result Do
		Row = Tree.Add();
		FillPropertyValues(Row, Item);
	EndDo;
	Items.FormPages.CurrentPage = Items.PageTree;
	
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
	Items.FormPages.CurrentPage = Items.PageDiff;
	
EndProcedure

&AtClient
Procedure DiffSelection(Item, SelectedRow, Field, StandardProcessing)
	
	Row = Diff.FindByID(SelectedRow);
	If Row = Undefined Then
		Return;
	EndIf;
	BinaryData = git.blob(Row.new_id);
	TextDocument = New TextDocument;
	TextDocument.Read(BinaryData.OpenStreamForRead());
	TextDocument.Show();
	
EndProcedure

&AtClient
Function ReadBlob(id)
	
	If git.isBinary(id) Then
		Return "binary";
	Else
		BinaryData = git.blob(id);
		If TypeOf(BinaryData) = Type("BinaryData") Then
			TextReader = New TextReader;
			TextReader.Open(BinaryData.OpenStreamForRead(), TextEncoding.UTF8);
			Return TextReader.Read();
		Else
			Return "";
		EndIf;
	EndIf;
	
EndFunction

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
	
	DiffEditor = VADiffEditor();
	DiffEditor.setVisible(True);
	
	If IsBlankString(Row.status) Then
		DiffEditor.setVisible(False);
		Return;
	Else
		DiffEditor.setVisible(True);
	EndIf;
	
	DiffEditor.setValue(OldFileText(Row), Row.old_name, NewFileText(Row), Row.new_name);
	
EndProcedure

&AtClient
Procedure OpenBlob(Команда)
	
	Row = Items.Status.CurrentData;
	If Row = Undefined Then
		Return;
	EndIf;
	
	NewText = NewFileText(Row);
	VanessaEditor = VanessaEditor();
	VanessaEditor.setVisible(True);
	VanessaEditor.setValue(NewText, Row.new_name);
	
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
		File = New File(SelectedFiles[0]);
		Title = File.Name;
		Directory = File.FullName;
		NotifyDescription = New NotifyDescription("FindFolderEnd", ThisForm, File.FullName);
		git.BeginCallingFind(NotifyDescription, SelectedFiles[0]);
	EndIf;
	
EndProcedure

&AtClient
Procedure FindFolderEnd(ResultCall, ParametersCall, AdditionalParameters) Export
	
	JsonData = JsonLoad(ResultCall);
	If JsonData.Success Then
		NotifyDescription = New NotifyDescription("OpenRepositoryEnd", ThisForm);
		git.BeginCallingOpen(NotifyDescription, JsonData.Result);
	Else
		Items.MainPages.CurrentPage = Items.InitializePage;
	EndiF;
	
EndProcedure

&AtClient
Procedure OpenRepositoryEnd(ResultCall, ParametersCall, AdditionalParameters) Export
	
	JsonData = JsonLoad(ResultCall);
	If JsonData.Success Then
		git.BeginCallingStatus(GitStatusNotify());
		Items.MainPages.CurrentPage = Items.StatusPage;
	EndiF;
	
EndProcedure

&AtClient
Procedure CloseFolder(Command)
	
	Items.MainPages.CurrentPage = Items.FolderPage;
	git.BeginCallingClose(New NotifyDescription);
	VanessaEditor().setVisible(False);
	Directory = Undefined;
	Title = Undefined;
	
EndProcedure

&AtClient
Procedure RefreshStatus(Command)
	
	git.BeginCallingStatus(GitStatusNotify());
	
EndProcedure

&AtClient
Procedure CloneRepository(Command)
	
	NewName = GetFormName("Clone");
	OpenForm(NewName, , ThisForm, New Uuid);
	
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
	
EndProcedure	

&AtClient
Procedure ShowExplorer(Command)
	
	If Not IsBlankString(Directory) Then
		ClearAllItems();
		Items.MainPages.CurrentPage = Items.ExplorerPage;
		FillExplorerItems(Explorer.GetItems(), Directory);
		CurrentItem = Items.Explorer;
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowSearch(Command)

	If Not IsBlankString(Directory) Then
		ClearAllItems();
		Items.MainPages.CurrentPage = Items.SearchPage;
		CurrentItem = Items.SearchText;
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowControl(Command)

	If Not IsBlankString(Directory) Then
		ClearAllItems();
		Items.MainPages.CurrentPage = Items.StatusPage;
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
		id = git.file(Data.fullname, True);
		Text = ReadBlob(id);
		VanessaEditor().setVisible(True);
		VanessaEditor().setValue(Text, Data.name);
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
		id = git.file(Data.path, True);
		Text = ReadBlob(id);
		VanessaEditor().setVisible(True);
		VanessaEditor().setValue(Text, Data.name);
	EndIf;
	
EndProcedure

