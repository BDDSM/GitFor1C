﻿#ifndef __CLIPBOARDCONTROL_H__
#define __CLIPBOARDCONTROL_H__

#include "stdafx.h"
#include "AddInBase.h"
#include "GitManager.h"

///////////////////////////////////////////////////////////////////////////////
// class WindowsControl
class GitControl : public AddInBase
{
private:
	enum Props
	{
		eVersion = 0,
	};

	enum Methods
	{
		eInit = 0,
		eOpen,
		eFind,
		eInfo,
		eAdd,
		eRemove,
		eClone,
		eCommit,
		eStatus,
	};

private:
	GitManager m_manager = this;
	static const wchar_t* m_ExtensionName;
	static const std::vector<Alias> m_PropList;
	static const std::vector<Alias> m_MethList;
	const wchar_t* ExtensionName() const override { return m_ExtensionName; };
	const std::vector<Alias>& PropList() const override { return m_PropList; };
	const std::vector<Alias>& MethList() const override { return m_MethList; };

public:
	bool ADDIN_API GetPropVal(const long lPropNum, tVariant* pvarPropVal) override;
	bool ADDIN_API SetPropVal(const long lPropNum, tVariant* pvarPropVal) override;
	bool ADDIN_API CallAsProc(const long lMethodNum, tVariant* paParams, const long lSizeArray) override;
	bool ADDIN_API CallAsFunc(const long lMethodNum, tVariant* pvarRetValue, tVariant* paParams, const long lSizeArray) override;
	bool ADDIN_API GetParamDefValue(const long lMethodNum, const long lParamNum, tVariant* pvarParamDefValue) override;
};

#endif //__CLIPBOARDCONTROL_H__
