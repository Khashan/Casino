pragma solidity >=0.6.0;

interface IRandomizer {
    function fetchRandom(
        bytes32 requestId,
        uint256 quantity,
        uint256 mod,
        uint256 offset
    ) external returns (uint256[] memory expandedValues);
}
