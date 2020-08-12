﻿#include "stdafx.h"

#ifdef _WINDOWS
#pragma setlocale("ru-RU" )
#else //_WINDOWS
#include <unistd.h>
#include <stdlib.h>
#include <signal.h>
#include <errno.h>
#include <iconv.h>
#include <sys/time.h>
#endif //_WINDOWS

#include "GitControl.h"
#include "FileFinder.h"
#include "version.h"

const wchar_t* GitControl::m_ExtensionName = L"GitFor1C";

const std::vector<AddInBase::Alias> GitControl::m_PropList{
	Alias(eVersion   , false , L"Version"   , L"Версия"),
	Alias(eSignature , false , L"Signature" , L"Подпись"),
	Alias(eRemoteList, false , L"RemoteList" , L"RemoteList"),
};

const std::vector<AddInBase::Alias> GitControl::m_MethList{
	Alias(eInit          , 2, true  , L"Init"            , L"Init"),
	Alias(eClone   		 , 2, true  , L"Clone"      	 , L"Clone"),
	Alias(eFind    		 , 1, true  , L"Find"       	 , L"Find"),
	Alias(eOpen    		 , 1, true  , L"Open"       	 , L"Open"),
	Alias(eClose   		 , 0, false , L"Close"       	 , L"Close"),
	Alias(eInfo    		 , 1, true  , L"Info"       	 , L"Info"),
	Alias(eCommit  		 , 1, true  , L"Commit"     	 , L"Commit"),
	Alias(eStatus  		 , 0, true  , L"Status"     	 , L"Status"),
	Alias(eAdd     		 , 2, true  , L"Add"        	 , L"Add"),
	Alias(eReset   		 , 1, true  , L"Reset"        	 , L"Reset"),
	Alias(eRemove  		 , 1, true  , L"Remove"     	 , L"Remove"),
	Alias(eDiscard  	 , 1, true  , L"Discard"     	 , L"Discard"),
	Alias(eHistory 		 , 1, true  , L"History"    	 , L"History"),
	Alias(eBlob 		 , 2, true  , L"Blob"    	     , L"Blob"),
	Alias(eDiff 		 , 2, true  , L"Diff"    	     , L"Diff"),
	Alias(eFile 		 , 2, true  , L"File"    	     , L"File"),
	Alias(eTree 		 , 1, true  , L"Tree"    	     , L"Tree"),
	Alias(eFullpath      , 1, true  , L"Fullpath"    	 , L"Fullpath"),
	Alias(eIsBinary      , 2, true  , L"IsBinary"    	 , L"IsBinary"),
	Alias(eGetEncoding   , 1, true  , L"GetEncoding"  	 , L"GetEncoding"),
	Alias(eSetAuthor     , 2, false , L"SetAuthor"  	 , L"SetAuthor"),
	Alias(eSetCommitter  , 2, false , L"SetCommitter"    , L"SetCommitter"),
	Alias(eFindFiles     , 4, true  , L"FindFiles"       , L"НайтиФайлы"),
};

/////////////////////////////////////////////////////////////////////////////
// ILanguageExtenderBase
//---------------------------------------------------------------------------//
bool GitControl::GetPropVal(const long lPropNum, tVariant* pvarPropVal)
{
	switch (lPropNum) {
	case eVersion:
		return VA(pvarPropVal) << MB2WC(VER_FILE_VERSION_STR);
	case eRemoteList:
		return VA(pvarPropVal) << m_manager.remoteList();
	case eSignature:
		return VA(pvarPropVal) << m_manager.signature();
	default:
		return false;
	}
}

#define ASSERT(c, m) if (!(c)) { addError(m); return false; }

//---------------------------------------------------------------------------//
bool GitControl::SetPropVal(const long lPropNum, tVariant* pvarPropVal)
{
	return false;
}
//---------------------------------------------------------------------------//
bool GitControl::CallAsProc(const long lMethodNum, tVariant* paParams, const long lSizeArray)
{
	switch (lMethodNum) {
	case eSetAuthor:
		return m_manager.setAuthor(VarToStr(paParams), VarToStr(paParams + 1));
	case eSetCommitter:
		return m_manager.setCommitter(VarToStr(paParams), VarToStr(paParams + 1));
	case eClose:
		return m_manager.close();
	}
	return false;
}
//---------------------------------------------------------------------------//
bool GitControl::CallAsFunc(const long lMethodNum, tVariant* pvarRetValue, tVariant* paParams, const long lSizeArray)
{
	switch (lMethodNum) {
	case eInit:
		return VA(pvarRetValue) << m_manager.init(VarToStr(paParams), VarToBool(paParams + 1));
	case eClone:
		return VA(pvarRetValue) << m_manager.clone(VarToStr(paParams), VarToStr(paParams + 1));
	case eOpen:
		return VA(pvarRetValue) << m_manager.open(VarToStr(paParams));
	case eFind:
		return VA(pvarRetValue) << m_manager.find(VarToStr(paParams));
	case eInfo:
		return VA(pvarRetValue) << m_manager.info(VarToStr(paParams));
	case eCommit:
		return VA(pvarRetValue) << m_manager.commit(VarToStr(paParams));
	case eAdd:
		return VA(pvarRetValue) << m_manager.add(VarToStr(paParams), VarToStr(paParams + 1));
	case eReset:
		return VA(pvarRetValue) << m_manager.reset(VarToStr(paParams));
	case eRemove:
		return VA(pvarRetValue) << m_manager.remove(VarToStr(paParams));
	case eDiscard:
		return VA(pvarRetValue) << m_manager.discard(VarToStr(paParams));
	case eHistory:
		return VA(pvarRetValue) << m_manager.history(VarToStr(paParams));
	case eDiff:
		return VA(pvarRetValue) << m_manager.diff(VarToStr(paParams), VarToStr(paParams + 1));
	case eTree:
		return VA(pvarRetValue) << m_manager.tree(VarToStr(paParams));
	case eFile:
		return VA(pvarRetValue) << m_manager.file(VarToStr(paParams), VarToBool(paParams + 1));
	case eFullpath:
		return VA(pvarRetValue) << m_manager.fullpath(VarToStr(paParams));
	case eStatus:
		return VA(pvarRetValue) << m_manager.status();
	case eGetEncoding:
		return VA(pvarRetValue) << m_manager.getEncoding(paParams);
	case eIsBinary:
		return VA(pvarRetValue) << m_manager.isBinary(paParams, paParams + 1);
	case eBlob:
		return m_manager.blob(VarToStr(paParams), paParams + 1, pvarRetValue);
	case eFindFiles:
		return VA(pvarRetValue) << FileFinder(VarToStr(paParams + 2), VarToBool(paParams + 3)).find(VarToStr(paParams), VarToStr(paParams + 1));
	default:
		return false;
	}
}
//---------------------------------------------------------------------------//
static bool DefStr(tVariant* pvar)
{
	TV_VT(pvar) = VTYPE_PWSTR;
	TV_WSTR(pvar) = nullptr;
	return true;
}
static bool DefInt(tVariant* pvar, int value = 0)
{
	TV_VT(pvar) = VTYPE_I4;
	TV_I4(pvar) = value;
	return true;
}
static bool DefBool(tVariant* pvar, bool value = false)
{
	TV_VT(pvar) = VTYPE_BOOL;
	TV_BOOL(pvar) = value;
	return true;
}
//---------------------------------------------------------------------------//
bool GitControl::GetParamDefValue(const long lMethodNum, const long lParamNum, tVariant* pvarParamDefValue)
{
	switch (lMethodNum) {
	case eAdd: if (lParamNum == 1) return DefStr(pvarParamDefValue); else return false;
	case eBlob: if (lParamNum == 1) return DefInt(pvarParamDefValue); else return false;
	case eInit: if (lParamNum == 1) return DefBool(pvarParamDefValue); else return false;
	case eFile: if (lParamNum == 1) return DefBool(pvarParamDefValue); else return false;
	case eTree: if (lParamNum == 0) return DefStr(pvarParamDefValue); else return false;
	case eHistory: if (lParamNum == 0) return DefStr(pvarParamDefValue); else return false;
	case eIsBinary: if (lParamNum == 1) return DefInt(pvarParamDefValue); else return false;
	default: return false;
	}
}
