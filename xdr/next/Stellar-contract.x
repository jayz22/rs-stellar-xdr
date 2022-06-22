// Copyright 2022 Stellar Development Foundation and contributors. Licensed
// under the Apache License, Version 2.0. See the COPYING file at the root
// of this distribution or at http://www.apache.org/licenses/LICENSE-2.0

% #include "xdr/Stellar-types.h"
namespace stellar
{
/*
 * Smart Contracts deal in SCVals. These are a (dynamic) disjoint union
 * between several possible variants, to allow storing generic SCVals in
 * generic data structures and passing them in and out of languages that
 * have simple or dynamic type systems.
 *
 * SCVals are (in WASM's case) stored in a tagged 64-bit word encoding. Most
 * signed 64-bit values in Stellar are actually signed positive values
 * (sequence numbers, timestamps, amounts), so we don't need the high bit
 * and can get away with 1-bit tagging and store them as "unsigned 63bit",
 * (u63) separate from everything else.
 *
 * We actually reserve the low _four_ bits, leaving 3 bits for 8 cases of
 * "non-u63 values", some of which have substructure of their own.
 *
 *    0x_NNNN_NNNN_NNNN_NNNX  - u63, for any even X
 *    0x_0000_000N_NNNN_NNN1  - u32
 *    0x_0000_000N_NNNN_NNN3  - i32
 *    0x_NNNN_NNNN_NNNN_NNN5  - static: void, true, false, ... (SCS_*)
 *    0x_IIII_IIII_TTTT_TTT7  - object: 32-bit index I, 28-bit type code T
 *    0x_NNNN_NNNN_NNNN_NNN9  - symbol: up to 10 6-bit identifier characters
 *    0x_NNNN_NNNN_NNNN_NNNb  - bitset: up to 60 bits
 *    0x_CCCC_CCCC_TTTT_TTTd  - status: 32-bit code C, 28-bit type code T
 *    0x_NNNN_NNNN_NNNN_NNNf  - reserved
 *
 * Up here in XDR we have variable-length tagged disjoint unions but no
 * bit-level packing, so we can be more explicit in their structure, at the
 * cost of spending more than 64 bits to encode many cases, and also having
 * to convert. It's a little non-obvious at the XDR level why there's a
 * split between SCVal and SCObject given that they are both immutable types
 * with value semantics; but the split reflects the split that happens in
 * the implementation, and marks a place where different implementations of
 * immutability (CoW, structural sharing, etc.) will likely occur.
 */

// A symbol is up to 10 chars drawn from [a-zA-Z0-9_], which can be packed
// into 60 bits with a 6-bit-per-character code, usable as a small key type
// to specify function, argument, tx-local environment and map entries
// efficiently.
typedef string SCSymbol<10>;

enum SCValType
{
    SCV_U63 = 0,
    SCV_U32 = 1,
    SCV_I32 = 2,
    SCV_STATIC = 3,
    SCV_OBJECT = 4,
    SCV_SYMBOL = 5,
    SCV_BITSET = 6,
    SCV_STATUS = 7
};

% struct SCObject;

enum SCStatic
{
    SCS_VOID = 0,
    SCS_TRUE = 1,
    SCS_FALSE = 2,
    SCS_LEDGER_KEY_CONTRACT_CODE_WASM = 3
};

enum SCStatusType
{
    SST_OK = 0,
    SST_UNKNOWN_ERROR = 1,
    SST_HOST_VALUE_ERROR = 2,
    SST_HOST_OBJECT_ERROR = 3,
    SST_HOST_FUNCTION_ERROR = 4,
    SST_HOST_STORAGE_ERROR = 5,
    SST_HOST_CONTEXT_ERROR = 6,
    SST_VM_ERROR = 7
    // TODO: add more
};

enum SCHostValErrorCode
{
    HOST_VALUE_UNKNOWN_ERROR = 0,
    RESERVED_TAG_VALUE = 1,
    UNEXPECTED_VAL_TYPE = 2,
    U63_OUT_OF_RANGE = 3,
    U32_OUT_OF_RANGE = 4,
    STATIC_UNKNOWN = 5,
    MISSING_OBJECT = 6,
    SYMBOL_TOO_LONG = 7,
    SYMBOL_BAD_CHAR = 8,
    SYMBOL_CONTAINS_NON_UTF8 = 9,
    BITSET_TOO_MANY_BITS = 10,
    STATUS_UNKNOWN = 11
};

enum SCHostObjErrorCode
{
    HOST_OBJECT_UNKNOWN_ERROR = 0,
    UNKNOWN_HOST_OBJECT_REFERENCE = 1,
    UNEXPECTED_HOST_OBJECT_TYPE = 2,
    OBJECT_HANDLE_EXCEEDS_U32_MAX = 3,
    ACCESSING_HOST_OBJECT_OUT_OF_BOUND = 4,
    VEC_INDEX_OUT_OF_BOUND = 5,
    VEC_INDEX_OVERFLOW = 6,
    VEC_VALUE_NOT_EXIST = 7,
    INVALID_CONTRACT_HASH = 8
};

enum SCHostFnErrorCode
{
    HOST_FN_UNKNOWN_ERROR = 0,
    UNEXPECTED_HOST_FUNCTION_ACTION = 1,
    UNEXPECTED_ARGS = 2,
    INVALID_ARGS = 3,
    WRONG_INPUT_ARG_TYPE = 4
};

enum SCHostStorageErrorCode
{
    HOST_STORAGE_UNKNOWN_ERROR = 0,
    EXPECT_CONTRACT_DATA = 1,
    READWRITE_ACCESS_TO_READONLY_ENTRY = 2,
    ACCESS_TO_UNKNOWN_ENTRY = 3,
    MISSING_KEY_IN_GET = 4,
    GET_ON_DELETED_KEY = 5
};

enum SCHostContextErrorCode
{
    HOST_CONTEXT_UNKNOWN_ERROR = 0,
    NO_CONTRACT_RUNNING = 1
};

enum SCUnknownErrorCode
{
    UNKNOWN_GENERAL_ERROR = 0,
    UNKNOWN_XDR_ERROR = 1,
    UNKNOWN_WASMI_ERROR = 2,
    UNKNOWN_PARITY_WASMI_ELEMENTS_ERROR = 3
};

union SCStatus switch (SCStatusType type)
{
case SST_OK:
    void;
case SST_UNKNOWN_ERROR:
    SCUnknownErrorCode unknownCode;
case SST_HOST_VALUE_ERROR:
    SCHostValErrorCode errorCode;
case SST_HOST_OBJECT_ERROR:
    SCHostObjErrorCode errorCode;
case SST_HOST_FUNCTION_ERROR:
    SCHostFnErrorCode errorCode;
case SST_HOST_STORAGE_ERROR:
    SCHostStorageErrorCode errorCode;
case SST_HOST_CONTEXT_ERROR:
    SCHostContextErrorCode errorCode;
case SST_VM_ERROR:
    uint32 errorCode;
};

union SCVal switch (SCValType type)
{
case SCV_U63:
    int64 u63;
case SCV_U32:
    uint32 u32;
case SCV_I32:
    int32 i32;
case SCV_STATIC:
    SCStatic ic;
case SCV_OBJECT:
    SCObject* obj;
case SCV_SYMBOL:
    SCSymbol sym;
case SCV_BITSET:
    uint64 bits;
case SCV_STATUS:
    SCStatus status;
};

enum SCObjectType
{
    // We have a few objects that represent non-stellar-specific concepts
    // like general-purpose maps, vectors, numbers, blobs.

    SCO_VEC = 0,
    SCO_MAP = 1,
    SCO_U64 = 2,
    SCO_I64 = 3,
    SCO_BINARY = 4,
    SCO_BIG_INT = 5,
    SCO_HASH = 6,
    SCO_PUBLIC_KEY = 7

    // TODO: add more
};

struct SCMapEntry
{
    SCVal key;
    SCVal val;
};

const SCVAL_LIMIT = 256000;

typedef SCVal SCVec<SCVAL_LIMIT>;
typedef SCMapEntry SCMap<SCVAL_LIMIT>;

enum SCNumSign
{
    NEGATIVE = -1,
    ZERO = 0,
    POSITIVE = 1
};

union SCBigInt switch (SCNumSign sign)
{
case ZERO:
    void;
case POSITIVE:
case NEGATIVE:
    opaque magnitude<256000>;
};

enum SCHashType
{
    SCHASH_SHA256 = 0
};

union SCHash switch (SCHashType type)
{
case SCHASH_SHA256:
    Hash sha256;
};

union SCObject switch (SCObjectType type)
{
case SCO_VEC:
    SCVec vec;
case SCO_MAP:
    SCMap map;
case SCO_U64:
    uint64 u64;
case SCO_I64:
    int64 i64;
case SCO_BINARY:
    opaque bin<SCVAL_LIMIT>;
case SCO_BIG_INT:
    SCBigInt bigInt;
case SCO_HASH:
    SCHash hash;
case SCO_PUBLIC_KEY:
    PublicKey publicKey;
};
}