pragma solidity ^0.6.5;

import "openzeppelin-old/access/Ownable.sol";
import "openzeppelin-old/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

import "./libs/IRandomizer.sol";

contract RandomizerMock is Ownable, IRandomizer, VRFConsumerBase {
    using SafeMath for uint256;

    bytes32 internal keyHash;
    uint256 internal fee;
    mapping(bytes32 => uint256) generatedRandoms;

    constructor(address casino)
        public
        VRFConsumerBase(
            0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
            0xa36085F69e2889c224210F603D836748e7dC0088 // LINK Token
        )
    {
        transferOwnership(casino);
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10**18; // 0.1 LINK (varies by network)
    }

    function getRandomNumber(uint256 userProvidedSeed)
        public
        onlyOwner
        returns (bytes32 requestId)
    {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK - fill contract"
        );

        return requestRandomness(keyHash, fee, userProvidedSeed);
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
