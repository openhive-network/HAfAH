#pragma once

#include <gmock/gmock.h>

#include "include/postgres_includes.hpp"


class IPostgresMock {
public:
    virtual ~IPostgresMock() = default;

    virtual Datum OidFunctionCall0Coll(Oid _functionId, Oid _collation) = 0;
    virtual void getTypeBinaryOutputInfo(Oid, Oid*, bool*) = 0;
    virtual void fmgr_info(Oid, FmgrInfo*) = 0;
    virtual bytea* SendFunctionCall(FmgrInfo *flinfo, Datum val) = 0;
    virtual Bitmapset *get_primary_key_attnos(Oid relid, bool deferrableOk, Oid *constraintOid) = 0;
    virtual void getTypeBinaryInputInfo(Oid _type, Oid* _typReceive, Oid* _typIOParam) = 0;
    virtual StringInfo makeStringInfo() = 0;
    virtual void appendBinaryStringInfo(StringInfo str, const char *data, int datalen) = 0;
    virtual Datum ReceiveFunctionCall(FmgrInfo *flinfo, fmStringInfo buf, Oid typioparam, int32 typmod) = 0;
    virtual void getTypeOutputInfo(Oid type, Oid *typOutput, bool *typIsVarlena) = 0;
    virtual char *OidOutputFunctionCall(Oid functionId, Datum val) = 0;

    //Bitmapset
    virtual int	bms_next_member(const Bitmapset* a, int prevbit) = 0;

};

class PostgresMock : public IPostgresMock {
public:
    MOCK_METHOD( Datum, OidFunctionCall0Coll, (Oid, Oid) );
    MOCK_METHOD( void,  getTypeBinaryOutputInfo, (Oid, Oid*, bool*) );
    MOCK_METHOD( void, fmgr_info, (Oid, FmgrInfo*) );
    MOCK_METHOD( bytea*, SendFunctionCall, (FmgrInfo*, Datum) );
    MOCK_METHOD( Bitmapset*, get_primary_key_attnos, (Oid, bool, Oid*) );
    MOCK_METHOD( void, getTypeBinaryInputInfo, (Oid, Oid*, Oid*) );
    MOCK_METHOD( StringInfo, makeStringInfo, () );
    MOCK_METHOD( void, appendBinaryStringInfo, (StringInfo, const char *, int) );
    MOCK_METHOD( Datum, ReceiveFunctionCall, (FmgrInfo*, fmStringInfo, Oid, int32 ) );
    MOCK_METHOD( void, getTypeOutputInfo, (Oid, Oid*, bool*) );
    MOCK_METHOD( char*, OidOutputFunctionCall, (Oid, Datum) );

    //Bitmapset
    MOCK_METHOD( int, bms_next_member, (const Bitmapset*, int));

    static std::shared_ptr<PostgresMock> create_and_get();

private:
    PostgresMock() = default;
};