pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../libs/IRandomizer.sol";

contract Randomizer is Ownable, IRandomizer {
    using SafeMath for uint256;

    mapping(bytes32 => uint256) generatedRandoms;

    constructor()
        public
        VRFConsumerBase(
            0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
            0xa36085F69e2889c224210F603D836748e7dC0088 // LINK Token
        )
    {
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10**18; // 0.1 LINK (varies by network)
    }

    function getRandomNumber(uint256 userProvidedSeed)
        public
        onlyOwner
        returns (bytes32 requestId)
    {
        requestId = keccak256(abi.encodePacked(keyHash, block.timestamp));

        fulfillRandomness(
            requestId,
            uint256(keccak256(block.timestamp, block.difficulty))
        );

        return requestId;
    }

    function fetchRandom(
        bytes32 requestId,
        uint256 quantity,
        uint256 mod,
        uint256 offset
    ) public override onlyOwner returns (uint256[] memory expandedValues) {
        uint256 random = generatedRandoms[requestId];
        require(random > 0, "Invalid random");
        expandedValues = expand(random, quantity, mod, offset);
        generatedRandoms[requestId] = 0;

        return expandedValues;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        generatedRandoms[requestId] = randomness;
    }

    function expand(
        uint256 randomValue,
        uint256 n,
        uint256 mod,
        uint256 offset
    ) internal pure returns (uint256[] memory expandedValues) {
        expandedValues = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            expandedValues[i] = uint256(keccak256(abi.encode(randomValue, i)));

            if (mod > 0) {
                expandedValues[i] = expandedValues[i].mod(mod).add(offset);
            }
        }
        return expandedValues;
    }
}
