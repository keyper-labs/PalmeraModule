# Contract 

## Random

**Title:** Library Random

**Author:** general@palmeradao.xyz

### rand

```solidity
function rand(uint256 _seed) public view returns (uint256)
```

_Generate random uint256 <= 256^2_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _seed | uint256 | number seed to generate random number |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | uint |

### randint

```solidity
function randint() internal view returns (uint256)
```

_Generate random uint256 <= 256^2 with seed = block.timestamp_

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | uint |

### randrange

```solidity
function randrange(uint256 a, uint256 b) internal view returns (uint256)
```

_Generate random uint256 in range [a, b]_

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | uint |

