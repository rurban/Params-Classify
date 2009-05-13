#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifndef HvNAME_get
# define HvNAME_get(hv) HvNAME(hv)
#endif

#define sv_is_string(sv) \
	(SvTYPE(sv) != SVt_PVGV && \
	 (SvFLAGS(sv) & (SVf_IOK|SVf_NOK|SVf_POK|SVp_IOK|SVp_NOK|SVp_POK)))

const char *
ref_type(SV *referent)
{
	switch(SvTYPE(referent)) {
		case SVt_NULL: case SVt_IV: case SVt_NV: case SVt_RV:
		case SVt_PV: case SVt_PVIV: case SVt_PVNV:
		case SVt_PVMG: case SVt_PVLV: case SVt_PVGV:
			return "SCALAR";
		case SVt_PVAV: return "ARRAY";
		case SVt_PVHV: return "HASH";
		case SVt_PVCV: return "CODE";
		case SVt_PVFM: return "FORMAT";
		case SVt_PVIO: return "IO";
		default: croak("unknown SvTYPE, please update me");
	}
}

const char *
blessed_class(SV *referent)
{
	HV *stash = SvSTASH(referent);
	const char *name = HvNAME_get(stash);
	return name ? name : "__ANON__";
}

bool
call_bool_method(SV *objref, const char *methodname, SV *arg)
{
	dSP;
	int retcount;
	SV *ret;
	bool retval;
	ENTER;
	SAVETMPS;
	PUSHMARK(SP);
	XPUSHs(objref);
	XPUSHs(arg);
	PUTBACK;
	retcount = call_method(methodname, G_SCALAR);
	SPAGAIN;
	if(retcount != 1) croak("call_method misbehaving");
	ret = POPs;
	retval = !!SvTRUE(ret);
	PUTBACK;
	FREETMPS;
	LEAVE;
	return retval;
}

MODULE = Params::Classify PACKAGE = Params::Classify

char *
scalar_class(SV *arg)
PROTOTYPE: $
CODE:
	if(SvTYPE(arg) == SVt_PVGV) {
		RETVAL = "GLOB";
	} else if(!SvOK(arg)) {
		RETVAL = "UNDEF";
	} else if(SvROK(arg)) {
		RETVAL = SvOBJECT(SvRV(arg)) ? "BLESSED" : "REF";
	} else {
		RETVAL = "STRING";
	}
OUTPUT:
	RETVAL

bool
is_undef(SV *arg)
PROTOTYPE: $
CODE:
	RETVAL = SvTYPE(arg) != SVt_PVGV && !SvOK(arg);
OUTPUT:
	RETVAL

bool
is_string(SV *arg)
PROTOTYPE: $
CODE:
	RETVAL = sv_is_string(arg);
OUTPUT:
	RETVAL

bool
is_glob(SV *arg)
PROTOTYPE: $
CODE:
	RETVAL = SvTYPE(arg) == SVt_PVGV;
OUTPUT:
	RETVAL

bool
is_ref(SV *arg, SV *type = 0)
PROTOTYPE: $;$
CODE:
	if(type && !sv_is_string(type))
		croak("type argument must be a string");
	if(!SvROK(arg) || SvOBJECT(SvRV(arg))) {
		RETVAL = 0;
	} else if(type) {
		char const *actual_type = ref_type(SvRV(arg));
		char const *check_type;
		STRLEN check_len;
		check_type = SvPV(type, check_len);
		RETVAL = check_len == strlen(actual_type) &&
				!strcmp(check_type, actual_type);
	} else {
		RETVAL = 1;
	}
OUTPUT:
	RETVAL

char *
ref_type(SV *arg)
PROTOTYPE: $
CODE:
	if(!SvROK(arg) || SvOBJECT(SvRV(arg))) {
		RETVAL = 0;
	} else {
		RETVAL = (char *)ref_type(SvRV(arg));
	}
OUTPUT:
	RETVAL

bool
is_blessed(SV *arg, SV *class = 0)
PROTOTYPE: $;$
CODE:
	if(class && !sv_is_string(class))
		croak("class argument must be a string");
	if(!SvROK(arg) || !SvOBJECT(SvRV(arg))) {
		RETVAL = 0;
	} else if(class) {
		PUTBACK;
		RETVAL = call_bool_method(arg, "isa", class);
		SPAGAIN;
	} else {
		RETVAL = 1;
	}
OUTPUT:
	RETVAL

char *
blessed_class(SV *arg)
PROTOTYPE: $
CODE:
	if(!SvROK(arg) || !SvOBJECT(SvRV(arg))) {
		RETVAL = 0;
	} else {
		RETVAL = (char *)blessed_class(SvRV(arg));
	}
OUTPUT:
	RETVAL

bool
is_strictly_blessed(SV *arg, SV *class = 0)
PROTOTYPE: $;$
CODE:
	if(class && !sv_is_string(class))
		croak("class argument must be a string");
	if(!SvROK(arg) || !SvOBJECT(SvRV(arg))) {
		RETVAL = 0;
	} else if(class) {
		char const *actual_class = blessed_class(SvRV(arg));
		char const *check_class;
		STRLEN check_len;
		check_class = SvPV(class, check_len);
		RETVAL = check_len == strlen(actual_class) &&
				!strcmp(check_class, actual_class);
	} else {
		RETVAL = 1;
	}
OUTPUT:
	RETVAL

bool
is_able(SV *arg, SV *methods)
PROTOTYPE: $$
CODE:
	RETVAL = 0;
	PUTBACK;
	if(!SvROK(arg) || !SvOBJECT(SvRV(arg))) goto out;
	if(sv_is_string(methods)) {
		if(!call_bool_method(arg, "can", methods)) goto out;
	} else {
		AV *methods_av;
		I32 alen, pos;
		if(!SvROK(methods) || SvOBJECT(SvRV(methods)) ||
				SvTYPE(SvRV(methods)) != SVt_PVAV)
			croak("methods argument must be a string or array");
		methods_av = (AV*)SvRV(methods);
		alen = av_len(methods_av);
		for(pos = 0; pos <= alen; pos++) {
			SV **m_ptr = av_fetch(methods_av, pos, 0);
			if(!m_ptr || !sv_is_string(*m_ptr))
				croak("method name must be a string");
			if(!call_bool_method(arg, "can", *m_ptr)) goto out;
		}
	}
	RETVAL = 1;
	out:
	SPAGAIN;
OUTPUT:
	RETVAL
