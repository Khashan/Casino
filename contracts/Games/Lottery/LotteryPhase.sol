pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LotteryPhase is Ownable {
    enum Phase {INIT, STARTING, OPEN, CLOSING}

    mapping(Phase => uint256) phaseTimer;

    event PhaseTimer(uint8 phaseId, uint256 timer);

    constructor() {
        phaseTimer[Phase.INIT] = 0;
        phaseTimer[Phase.STARTING] = 10 hours;
        phaseTimer[Phase.OPEN] = 12 hours;
        phaseTimer[Phase.CLOSING] = 2 hours;
    }

    function getPhaseTimer(uint8 phaseId) external view returns (uint256) {
        return phaseTimer[Phase(phaseId)];
    }

    function setPhaseTimer(uint8 phaseId, uint256 timer) external onlyOwner {
        phaseTimer[Phase(phaseId)] = timer;

        emit PhaseTimer(phaseId, timer);
    }
}
