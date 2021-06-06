pragma solidity >=0.6.0;

interface IRandomizer {
    function getRandomNumber(uint256 userProvidedSeed)
        external
        returns (bytes32 requestId);

    function fetchRandom(
        bytes32 requestId,
        uint256 quantity,
        uint256 mod,
        uint256 offset
    ) external returns (uint256[] memory expandedValues);
}
