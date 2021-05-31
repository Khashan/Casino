pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

interface IRandomizer is VRFConsumerBase {
    function fetchRandom(
        bytes32 requestId,
        uint256 quantity,
        uint256 mod,
        uint256 offset
    ) external returns (uint256[] memory expandedValues);
}
