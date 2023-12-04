from __future__ import annotations

from typing import Any, Final, Generic

from pydantic import Field
from pydantic.generics import GenericModel

from schemas._preconfigured_base_model import PreconfiguredBaseModel
from schemas.fields.assets.hive import AssetHiveHF26, AssetHiveLegacy, AssetHiveT
from schemas.fields.basic import (
    AccountName,
    PublicKey,
)
from schemas.fields.compound import LegacyChainProperties
from schemas.fields.hex import Sha256, TransactionId
from schemas.fields.integers import Uint32t, Uint64t
from schemas.operation import Operation

DEFAULT_FILL_OR_KILL: Final[bool] = False


class Pow2Input(PreconfiguredBaseModel):
    worker_account: AccountName
    prev_block: TransactionId
    nonce: Uint64t = Field(default_factory=lambda: Uint64t(0))


class Pow2(PreconfiguredBaseModel):
    input_: Pow2Input = Field(alias="input")
    pow_summary: Uint32t = Field(default_factory=lambda: Uint32t(0))



class EquihashPow(PreconfiguredBaseModel):
    input_: Sha256 = Field(alias="input")
    proof: Any
    prev_block: TransactionId
    pow_summary: Uint32t


class Pow2Work(PreconfiguredBaseModel):
    type_: str = Field(alias="type")
    value: Pow2 | EquihashPow


class _Pow2Operation(Operation, GenericModel, Generic[AssetHiveT]):
    __operation_name__ = "pow2"
    __offset__ = 30

    work: Pow2Work
    props: LegacyChainProperties[AssetHiveT]
    new_owner_key: PublicKey | None = None


class Pow2Operation(_Pow2Operation[AssetHiveHF26]):
    ...


class Pow2OperationLegacy(_Pow2Operation[AssetHiveLegacy]):
    ...
