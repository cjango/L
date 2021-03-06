# Feel Lucky 游戏合约

<!-- TOC -->

- [Feel Lucky 游戏合约](#feel-lucky-游戏合约)
    - [1 存储](#1-存储)
        - [1.1 statedb](#11-statedb)
        - [1.2 localdb](#12-localdb)
    - [2 接口](#2-接口)
        - [2.1 tx中的action](#21-tx中的action)
        - [2.2 对外查询接口](#22-对外查询接口)
            - [2.2.1 用户投注信息批量查询](#221-用户投注信息批量查询)
        - [2.3 响应数据](#23-响应数据)
        - [2.4 用户接口](#24-用户接口)
            - [2.4.1 创建投注交易](#241-创建投注交易)
            - [2.4.2 获取用户投注信息](#242-获取用户投注信息)
            - [2.4.3 奖池信息](#243-奖池信息)
    - [3 奖池维护](#3-奖池维护)
    - [4 整体流程](#4-整体流程)
    - [5 配置](#5-配置)

<!-- /TOC -->

## 1 存储
### 1.1 statedb

```proto
// 投注信息
message BetReq {
    int32 index = 1;
}

// 当前奖池信息
message BonusInfo {
    int32 userCount = 1;
    float bonusPool = 2; 
}
```

|key|val|说明|
|----|----|----|
|mavl-flucky-user-times:{address}|BetInfo|用户购买次数|
|mavl-flucky-bonul-info|BonusInfo|当前奖池信息|

### 1.2 localdb

```proto
// 用户投注信息
message BetInfo {
    int32 index = 1;
    string addr = 2;
    uint64 time = 3;
    int32 amount = 4;
    repeated int32 randNum = 5;
    int64 bonus = 6;
}
```

|key|val|说明|
|----|----|----|
|LODB-flucky-user-history:{address}:{idx}|BetInfo|用户投注信息|



## 2 接口
### 2.1 tx中的action
```proto
message FluckyAction {
    oneof value {
        FluckyBet bet = 1;
    }
    int32 ty = 6;
}

message FluckyBet {
	// 玩家购买key的数量
    int32 amount = 1;
}
```

### 2.2 对外查询接口 
#### 2.2.1 用户投注信息批量查询
```proto
message QueryBetInfoBatch {
    string addr = 1;
    int32 startIdx = 2;
    int32 endIdx = 3;
}

message QueryBetInfo {
    string addr = 1;
    int32 idx = 2;
}

message QueryBetTimes {
    string addr = 1;
}
```

### 2.3 响应数据
```proto
// 投注信息响应
message ReceiptBetInfo {
    BetInfo bet = 1;
}

message ReceiptBetInfoBatch {
    repeated BetInfo bets = 2;
}

message ReceiptBetTimes {
    BetReq bet = 1;
}

// 奖池信息响应
message ReceiptBonusInfo {
    int32 userCount = 1;
    float bonusPool = 2;
}
```

### 2.4 用户接口
#### 2.4.1 创建投注交易
请求结构：
```bash
{
    "amount":int32
}
```

|字段|类型|说明|
|----|----|----|
|amount|int32|用户投注的金额|

返回结构:
```bash
{
    "randNum":[int32],
    "bonus":float
}
```
|字段|类型|说明|
|----|----|----|
|randNum|int32数组|根据投注金额生成的随机数数组|
|bonus|float|randNum中最大随机数对应奖金|

#### 2.4.2 获取用户投注信息
请求结构：
```bash
{
    "addr":string,
    "startIndex":int32,
    "endIndex":int32,
}
```
|字段|类型|说明|
|----|----|----|
|addr|string|查询的用户地址|
|startIndex|int32|投注信息的起始index|
|endIndex|int32|投注信息的结束index|

响应结构：
```bash
{
    [
        {
            "index":int32,
            "addr":string,
            "time":uint64,
            "amount":int32,
            "randNum":[int32],
            "bonus":int64,
        }
    ]
}
```
|字段|类型|说明|
|----|----|----|
|index|int32|该用户地址投注信息的index|
|addr|string|用户投注地址|
|time|uint64|投注时间|
|amount|int32|用户投注金额|
|randNum|int32数组|随机数数组|
|bonus|int64|randNum最大随机数对应的奖金|

#### 2.4.3 奖池信息
响应结构:
```bash
{
    "bonus":float,
    "count":int32,
}
```

|字段|类型|说明|
|----|----|----|
|bonus|float|奖池中累积的全部奖金|
|count|int32|游戏累积参与人数|

## 3 游戏相关
### 3.1 奖金分成
根据随机数所在区间，确定分成比例：

|数值区间|分成比例|
|----|----|
|[0,5000]|投入金额的10%|
|[5001,8000]|投入金额的50%|
|[8001,9000]|投入金额的100%|
|[9001,9500]|奖池的0.5%|
|[9501,9900]|奖池的1%|
|[9901,9950]|奖池的5%|
|[9951,9990]|奖池的10%|
|[9991,9999)|奖池的20%|
|9999|奖池的50%|

### 3.2 投入分成比例
以1个BTY为基本投注单位，获取一次抽奖机会；

如果用户投入大于1BTY，则可以获取多次抽奖机会；多次抽奖机会时，合约会连续多次生成随机数，并取最大的那个作为开奖结果，用户投入金额和抽奖次数的关系如下：

|投入金额|抽奖次数|
|----|----|
|1 BTY|1|
|2 BTY|3|
|3 BTY|5|
|4 BTY|8|
|5 BTY|12|
|10 BTY|30|

### 3.3 奖池维护
在计算用户投注的奖金之前，对奖池剩余金额进行检测。

检测到奖池中的奖金超过最大额度时，将从奖池取出部分额度转入平台的账户地址中;当奖池奖金低于最小额度时，从平台账户中往奖池中转入指定额度。

## 4 整体流程
![Feel Lucky](https://github.com/lynAzrael/L/blob/master/chain33_plugin/flucky/resources/flucky_process.png)

## 5 配置
```toml
# 平台地址
platFormAddr="14KEKbYtKKQm4wMthSK9J4La4nAiidGozt"

# 奖池最大额度
maxBonus=100000
# 奖池最小额度
minBonus=500

# 奖池金额溢出，转出到平台账户的额度
bonusToPlatform=50000
# 奖池金额不足，从平台账户转入的额度
platformToBonus=500
```

## 6 随机数生成方案
由于此游戏合约的需要生成随机数的频率较高且一次有可能需要多个随机数，因此不太适合采用ticket中的随机数生成器。暂时使用如下方案，后续如有更优方法可以进行替换。

### 6.1 使用交易相关信息构造
交易的哈希txHash，以及交易所处位置index以及区块的打包时间blocktime这三个变量作为随机因子，对其之和进行哈希之后取模，生成一个[0,10000)范围内的数字。

当需要生成多个随机数时，使用上一次生成的随机数与index做运算后的结果作为新的index。