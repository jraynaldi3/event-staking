//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract EventStaking is Ownable{

    using Counters for Counters.Counter;

    event GatheringCreated(uint id, address organizer, string title, uint startDate);
    event GatheringEnded(uint id, address organizer, uint endDate);
    event RSVPSubmitted(uint id, address organizer, address sender);
    event CheckedId(uint id, address organizer, address sender);
    event RSVPwithdraw(uint id, address organizer, address withdrawer);


    uint checkInDuration;
    struct Gathering{
        uint id;
        address organizer;
        string title;
        uint RSVP;
        uint startDate;
        uint endDate;
    }

    mapping(address => Counters.Counter) idsToAddress;
    mapping(address => mapping(address => mapping(uint=>bool))) rsvpOfAddress;
    mapping(address => mapping(address => mapping(uint=>uint))) checkInCount; 

    Gathering[] gatherings;

    function createGathering( uint date, string memory title, uint _rsvp) external{
        uint newId = idsToAddress[msg.sender].current();
        gatherings.push(Gathering({
            id : newId,
            organizer: msg.sender,
            title: title,
            RSVP: _rsvp,
            startDate: date,
            endDate: 0
        }));
        emit GatheringCreated(newId, msg.sender, title, date);
    }

    function getGathering(uint id, address organizer) public view returns(Gathering memory gathering){
        for (uint i = 0; i<gatherings.length; i++){
            if (gatherings[i].organizer==organizer&& gatherings[i].id==id){
                gathering = gatherings[i];
                break;
            }
        }
    }

    function getGatheringStorage(uint id, address organizer) internal view returns(Gathering storage){
        Gathering storage gathering;
        uint index;
        for (uint i = 0; i<gatherings.length; i++){
            if (gatherings[i].organizer==organizer&& gatherings[i].id==id){
                index = i;
                break;
            }
        }
        gathering = gatherings[index];
        return gathering;
    }

    function submitRsvp(uint id, address organizer) external payable {
        Gathering memory gathering = getGathering(id, organizer);
        require(msg.value > gathering.RSVP, "Not enough for RSVP");
        require(!rsvpOfAddress[msg.sender][organizer][id],"Already have RSVP");
        rsvpOfAddress[msg.sender][organizer][id] = true;
        emit RSVPSubmitted(id, organizer, msg.sender);
    }

    function isCheckInTime(uint id, address organizer) internal view returns(bool){
        Gathering memory gathering = getGathering(id, organizer);
        if(block.timestamp > gathering.startDate && block.timestamp < gathering.startDate + checkInDuration){
            return true;
        }
        if(block.timestamp > gathering.endDate && block.timestamp < gathering.endDate + checkInDuration){
            return true;
        }
        return false;
    }

    function checkIn(uint id, address organizer) external {
        require(isCheckInTime(id, organizer), "Not in check in time");
        require(rsvpOfAddress[msg.sender][organizer][id],"Not registered RSVP");
        checkInCount[msg.sender][organizer][id] ++;
        emit CheckedId(id, organizer, msg.sender);
    }

    function endGathering(uint id) external {
        Gathering storage gathering = getGatheringStorage(id, msg.sender);
        require(gathering.organizer == msg.sender, "Gathering not exist");
        gathering.endDate = block.timestamp;
        emit GatheringEnded(id, msg.sender, block.timestamp);
    }

    function withdrawRsvp(uint id, address organizer) external {
        require(rsvpOfAddress[msg.sender][organizer][id],"You don't have RSVP for this event");
        require(checkInCount[msg.sender][organizer][id] == 2, "You are not coming for the event");
        Gathering memory gathering = getGathering(id,organizer);
        (bool success,) = msg.sender.call{value: gathering.RSVP}("");
        require(success,"Withdraw failed");
        rsvpOfAddress[msg.sender][organizer][id] = false;
        emit RSVPwithdraw(id, organizer, msg.sender);
    }
}
