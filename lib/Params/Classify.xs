#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define PERL_VERSION_DECIMAL(r,v,s) (r*1000000 + v*1000 + s)
#define PERL_DECIMAL_VERSION \
	PERL_VERSION_DECIMAL(PERL_REVISION,PERL_VERSION,PERL_SUBVERSION)
#define PERL_VERSION_GE(r,v,s) \
	(PERL_DECIMAL_VERSION >= PERL_VERSION_DECIMAL(r,v,s))

#ifndef HvNAME_get
# define HvNAME_get(hv) HvNAME(hv)
#endif

#define sv_is_glob(sv) (SvTYPE(sv) == SVt_PVGV)

#if PERL_VERSION_GE(5,11,0)
# define sv_is_regexp(sv) (SvTYPE(sv) == SVt_REGEXP)
#else /* <5.11.0 */
# define sv_is_regexp(sv) 0
#endif /* <5.11.0 */

#define sv_is_undef(sv) (!sv_is_glob(sv) && !sv_is_regexp(sv) && !SvOK(sv))

#define sv_is_string(sv) \
	(!sv_is_glob(sv) && !sv_is_regexp(sv) && \
	 (SvFLAGS(sv) & (SVf_IOK|SVf_NOK|SVf_POK|SVp_IOK|SVp_NOK|SVp_POK)))

static svtype
read_reftype(SV *reftype)
{
	char *p;
	STRLEN l;
	if(!sv_is_string(reftype))
		croak("reference type argument is not a string\n");
	p = SvPV(reftype, l);
	if(strlen(p) != l) {
		unrecognised:
		croak("invalid reference type\n");
	}
	switch(p[0]) {
		case 'S':
			if(!strcmp(p, "SCALAR")) return SVt_NULL;
			goto unrecognised;
		case 'A':
			if(!strcmp(p, "ARRAY")) return SVt_PVAV;
			goto unrecognised;
		case 'H':
			if(!strcmp(p, "HASH")) return SVt_PVHV;
			goto unrecognised;
		case 'C':
			if(!strcmp(p, "CODE")) return SVt_PVCV;
			goto unrecognised;
		case 'F':
			if(!strcmp(p, "FORMAT")) return SVt_PVFM;
			goto unrecognised;
		case 'I':
			if(!strcmp(p, "IO")) return SVt_PVIO;
			goto unrecognised;
		default:
			goto unrecognised;
	}
}

static const char *
write_reftype(svtype t)
{
	switch(t) {
		case SVt_NULL: return "SCALAR";
		case SVt_PVAV: return "ARRAY";
		case SVt_PVHV: return "HASH";
		case SVt_PVCV: return "CODE";
		case SVt_PVFM: return "FORMAT";
		case SVt_PVIO: return "IO";
		default: croak("unknown SvTYPE, please update me\n");
	}
}

static const char *
display_reftype(svtype t)
{
	switch(t) {
		case SVt_NULL: return "scalar";
		case SVt_PVAV: return "array";
		case SVt_PVHV: return "hash";
		case SVt_PVCV: return "code";
		case SVt_PVFM: return "format";
		case SVt_PVIO: return "io";
		default: croak("unknown SvTYPE, please update me\n");
	}
}

static svtype
ref_type(SV *referent)
{
	svtype t = SvTYPE(referent);
	switch(SvTYPE(referent)) {
		case SVt_NULL: case SVt_IV: case SVt_NV:
#if !PERL_VERSION_GE(5,11,0)
		case SVt_RV:
#endif /* <5.11.0 */
		case SVt_PV: case SVt_PVIV: case SVt_PVNV:
		case SVt_PVMG: case SVt_PVLV: case SVt_PVGV:
#if PERL_VERSION_GE(5,11,0)
		case SVt_REGEXP:
#endif /* >=5.11.0 */
			return SVt_NULL;
		case SVt_PVAV: case SVt_PVHV: case SVt_PVCV: case SVt_PVFM:
		case SVt_PVIO:
			return t;
		default: croak("unknown SvTYPE, please update me\n");
	}
}

static const char *
blessed_class(SV *referent)
{
	HV *stash = SvSTASH(referent);
	const char *name = HvNAME_get(stash);
	return name ? name : "__ANON__";
}

static bool
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
	if(retcount != 1) croak("call_method misbehaving\n");
	ret = POPs;
	retval = !!SvTRUE(ret);
	PUTBACK;
	FREETMPS;
	LEAVE;
	return retval;
}

static void
check_methods_arg(SV *methods_sv)
{
	AV *methods_av;
	I32 alen, pos;
	if(sv_is_string(methods_sv)) return;
	if(!SvROK(methods_sv) || SvOBJECT(SvRV(methods_sv)) ||
			SvTYPE(SvRV(methods_sv)) != SVt_PVAV)
		croak("methods argument is not a string or array\n");
	methods_av = (AV*)SvRV(methods_sv);
	alen = av_len(methods_av);
	for(pos = 0; pos <= alen; pos++) {
		SV **m_ptr = av_fetch(methods_av, pos, 0);
		if(!m_ptr || !sv_is_string(*m_ptr))
			croak("method name is not a string\n");
	}
}

MODULE = Params::Classify PACKAGE = Params::Classify

char *
scalar_class(SV *arg)
PROTOTYPE: $
CODE:
	if(sv_is_glob(arg)) {
		RETVAL = "GLOB";
	} else if(sv_is_regexp(arg)) {
		RETVAL = "REGEXP";
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
	RETVAL = !!sv_is_undef(arg);
OUTPUT:
	RETVAL

void
check_undef(SV *arg)
PROTOTYPE: $
CODE:
	if(!sv_is_undef(arg))
		croak("argument is not undefined\n");

bool
is_string(SV *arg)
PROTOTYPE: $
CODE:
	RETVAL = !!sv_is_string(arg);
OUTPUT:
	RETVAL

void
check_string(SV *arg)
PROTOTYPE: $
CODE:
	if(!sv_is_string(arg))
		croak("argument is not a string\n");

bool
is_glob(SV *arg)
PROTOTYPE: $
CODE:
	RETVAL = !!sv_is_glob(arg);
OUTPUT:
	RETVAL

void
check_glob(SV *arg)
PROTOTYPE: $
CODE:
	if(!sv_is_glob(arg))
		croak("argument is not a typeglob\n");

bool
is_regexp(SV *arg)
PROTOTYPE: $
CODE:
	RETVAL = !!sv_is_regexp(arg);
OUTPUT:
	RETVAL

void
check_regexp(SV *arg)
PROTOTYPE: $
CODE:
	if(!sv_is_regexp(arg))
		croak("argument is not a regexp\n");

bool
is_ref(SV *arg, SV *type_sv = 0)
PROTOTYPE: $;$
PREINIT:
	svtype type_svtype = 0;
CODE:
	if(type_sv) type_svtype = read_reftype(type_sv);
	if(!SvROK(arg) || SvOBJECT(SvRV(arg))) {
		RETVAL = 0;
	} else if(type_sv) {
		RETVAL = ref_type(SvRV(arg)) == type_svtype;
	} else {
		RETVAL = 1;
	}
OUTPUT:
	RETVAL

void
check_ref(SV *arg, SV *type_sv = 0)
PROTOTYPE: $;$
PREINIT:
	svtype type_svtype = 0;
CODE:
	if(type_sv) type_svtype = read_reftype(type_sv);
	if(!SvROK(arg) || SvOBJECT(SvRV(arg)) ||
			(type_sv && ref_type(SvRV(arg)) != type_svtype)) {
		croak("argument is not a reference to plain %s\n",
			type_sv ? display_reftype(type_svtype) : "object");
	}

char *
ref_type(SV *arg)
PROTOTYPE: $
CODE:
	if(!SvROK(arg) || SvOBJECT(SvRV(arg))) {
		RETVAL = 0;
	} else {
		RETVAL = (char *)write_reftype(ref_type(SvRV(arg)));
	}
OUTPUT:
	RETVAL

bool
is_blessed(SV *arg, SV *class_sv = 0)
PROTOTYPE: $;$
CODE:
	if(class_sv && !sv_is_string(class_sv))
		croak("class argument is not a string\n");
	if(!SvROK(arg) || !SvOBJECT(SvRV(arg))) {
		RETVAL = 0;
	} else if(class_sv) {
		PUTBACK;
		RETVAL = call_bool_method(arg, "isa", class_sv);
		SPAGAIN;
	} else {
		RETVAL = 1;
	}
OUTPUT:
	RETVAL

void
check_blessed(SV *arg, SV *class_sv = 0)
PROTOTYPE: $;$
PREINIT:
	int is_ok;
CODE:
	if(class_sv && !sv_is_string(class_sv))
		croak("class argument is not a string\n");
	is_ok = SvROK(arg) && SvOBJECT(SvRV(arg));
	if(is_ok && class_sv) {
		PUTBACK;
		is_ok = call_bool_method(arg, "isa", class_sv);
		SPAGAIN;
	}
	if(!is_ok) {
		croak("argument is not a reference to blessed %s\n",
			class_sv ? SvPV_nolen(class_sv) : "object");
	}

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
is_strictly_blessed(SV *arg, SV *class_sv = 0)
PROTOTYPE: $;$
CODE:
	if(class_sv && !sv_is_string(class_sv))
		croak("class argument is not a string\n");
	if(!SvROK(arg) || !SvOBJECT(SvRV(arg))) {
		RETVAL = 0;
	} else if(class_sv) {
		char const *actual_class = blessed_class(SvRV(arg));
		char const *check_class;
		STRLEN check_len;
		check_class = SvPV(class_sv, check_len);
		RETVAL = check_len == strlen(actual_class) &&
				!strcmp(check_class, actual_class);
	} else {
		RETVAL = 1;
	}
OUTPUT:
	RETVAL

void
check_strictly_blessed(SV *arg, SV *class_sv = 0)
PROTOTYPE: $;$
PREINIT:
	int is_ok;
CODE:
	if(class_sv && !sv_is_string(class_sv))
		croak("class argument is not a string\n");
	is_ok = SvROK(arg) && SvOBJECT(SvRV(arg));
	if(is_ok && class_sv) {
		char const *actual_class = blessed_class(SvRV(arg));
		char const *check_class;
		STRLEN check_len;
		check_class = SvPV(class_sv, check_len);
		is_ok = check_len == strlen(actual_class) &&
				!strcmp(check_class, actual_class);
	}
	if(!is_ok) {
		croak("argument is not a reference to strictly blessed %s\n",
			class_sv ? SvPV_nolen(class_sv) : "object");
	}

bool
is_able(SV *arg, SV *methods_sv)
PROTOTYPE: $$
CODE:
	check_methods_arg(methods_sv);
	RETVAL = 0;
	PUTBACK;
	if(!SvROK(arg) || !SvOBJECT(SvRV(arg))) goto out;
	if(!SvROK(methods_sv)) {
		if(!call_bool_method(arg, "can", methods_sv)) goto out;
	} else {
		AV *methods_av = (AV*)SvRV(methods_sv);
		I32 alen = av_len(methods_av), pos;
		for(pos = 0; pos <= alen; pos++) {
			SV *meth_sv = *av_fetch(methods_av, pos, 0);
			if(!call_bool_method(arg, "can", meth_sv)) goto out;
		}
	}
	RETVAL = 1;
	out:
	SPAGAIN;
OUTPUT:
	RETVAL

void
check_able(SV *arg, SV *methods_sv)
PROTOTYPE: $$
CODE:
	check_methods_arg(methods_sv);
	PUTBACK;
	if(!SvROK(methods_sv)) {
		if(!SvROK(arg) || !SvOBJECT(SvRV(arg)) ||
				!call_bool_method(arg, "can", methods_sv))
			croak("argument is not able to perform method \"%s\"\n",
				SvPV_nolen(methods_sv));
	} else {
		AV *methods_av = (AV*)SvRV(methods_sv);
		I32 alen = av_len(methods_av), pos;
		if(!SvROK(arg) || !SvOBJECT(SvRV(arg))) {
			if(alen == -1) {
				croak("argument is not able to perform "
						"at all\n");
			} else {
				SV *meth_sv = *av_fetch(methods_av, 0, 0);
				croak("argument is not able to perform "
						"method \"%s\"\n",
					SvPV_nolen(meth_sv));
			}
		}
		for(pos = 0; pos <= alen; pos++) {
			SV *meth_sv = *av_fetch(methods_av, pos, 0);
			if(!call_bool_method(arg, "can", meth_sv))
				croak("argument is not able to perform "
						"method \"%s\"\n",
					SvPV_nolen(meth_sv));
		}
	}
	SPAGAIN;
