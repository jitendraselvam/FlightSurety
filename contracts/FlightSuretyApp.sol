pragma solidity >=0.4.24 <0.6.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)
    FlightSuretyData flightSuretyData;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract
    bool private operational = true;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    uint256 constant M = 4; //keys
    bool private voteStatus = false;

 
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       EVENTS                                             */
    /********************************************************************************************/

    event RegisterAirline(address account);
    event InsurancePurchased(address airline, address sender, uint256 amount);
    event CreditInsurees(address airline, address passenger, uint256 credit);
    event AirlinesFunded(address funded, uint256 value);
    event WithdrawCompleted(address sender, uint256 amount);

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address dataContract) public 
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract); //register dataContract
        flightSuretyData.registerAirline(contractOwner, true); //register first flight

        emit RegisterAirline(contractOwner);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            pure 
                            returns(bool) 
    {
        return true;  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline(address airline)
                            external
                            requireIsOperational
                            returns(bool success, uint256 votes)
    {
        //checks
        require(airline != address(0), "'account' is not a valid address.");
        require(!flightSuretyData.getAirlineRegistrationStatus(airline), "Airline already exists");
        require(flightSuretyData.getAirlineOperatingStatus(msg.sender),"Requested airline is not operational");

        uint256 multicallLength = flightSuretyData.multiCallsLength();

        if (M > multicallLength){
            //register airline without voting
            flightSuretyData.registerAirline(airline, false);
            emit RegisterAirline(airline);
            return (true, 0);
        } else {
            if (voteStatus) {
                uint256 numOfVotes = flightSuretyData.getVoteCounter(airline);

                if(numOfVotes >= multicallLength) {
                    //votes passed and register airline
                    flightSuretyData.registerAirline(airline, false);
                    voteStatus=false;
                    flightSuretyData.resetVoteCounter(airline);
                    emit RegisterAirline(airline);
                    return (true, numOfVotes);
                } else {
                    //Do not register airlines
                     flightSuretyData.resetVoteCounter(airline);
                    return (false, numOfVotes);
                }
            } else {
                //start a new vote
                return (false, 0);
            }
        }

        return (success, 0);
    }

    /**
     * @dev Method to register the fifth and beyond airlines
     *
     */

    function approveAirlineRegistration(address airline, bool vote)
        public
        requireIsOperational
    {
        require(!flightSuretyData.getAirlineRegistrationStatus(airline),"Airline is already registered");
        require(flightSuretyData.getAirlineOperatingStatus(msg.sender), "Airline must be operational");

        if (vote == true) {
            // Check and avoid duplicate vote for the same airline
            bool isDuplicate = false;
            uint256 voteCount = 1;
            isDuplicate = flightSuretyData.getVoterStatus(msg.sender);

            // Check to avoid registering same airline multiple times
            require(!isDuplicate, "Caller has already registered a vote");
            flightSuretyData.addVoters(msg.sender);
            flightSuretyData.addVoterCounter(airline, voteCount);
        }
        voteStatus = true;
    }

     /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
     function fund(
                                    ) public 
                                    payable
                                    requireIsOperational 
    {
        require(msg.value == 10 ether, "10 Ether is Required");
        require(!flightSuretyData.getAirlineOperatingStatus(msg.sender),"Airline is already insured");

        flightSuretyData.fund(msg.sender, msg.value);
        flightSuretyData.setAirlineOperatingStatus(msg.sender, true);
        emit AirlinesFunded(msg.sender, msg.value);
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */
    function processFlightStatus(
                                    address airline,
                                    string flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                ) public
    {
        address passenger;
        uint256 amountPaid;
        (passenger, amountPaid) = flightSuretyData.getInsuredPassenger_amount(airline);

        require((address(0)!= passenger) && (address(0)!=airline), 'accounts are not valid');
        require(amountPaid > 0, "Passenger is not insured");

        if ((statusCode == STATUS_CODE_LATE_AIRLINE) || (statusCode == STATUS_CODE_LATE_TECHNICAL)) {
            uint256 creditAmount = amountPaid.mul(3).div(2);
            flightSuretyData.creditInsurees(airline, passenger, creditAmount);
            emit CreditInsurees(airline, passenger, creditAmount);
        }
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp                            
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 

        /**
     * @dev Buy insurance for a flight
     *
     */
    function buy(address airline) external payable requireIsOperational {
        require(flightSuretyData.getAirlineOperatingStatus(airline),"Airline must be operational");
        require((msg.value > 0 ether) && (msg.value <= 1 ether),"Insurance must be between 0 ether to 1 ether");

        flightSuretyData.buy(airline, msg.sender, msg.value);
        emit InsurancePurchased(airline, msg.sender, msg.value);
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay() external requireIsOperational {
        require(flightSuretyData.getPassengerCredit(msg.sender) > 0,"Account has No balance");

        uint256 balance = flightSuretyData.withdraw(msg.sender);
        msg.sender.transfer(balance);

        emit WithdrawCompleted(msg.sender, balance);
    }

    function getPassengerCreditedAmount() external returns (uint256) {
        uint256 credit = flightSuretyData.getPassengerCredit(msg.sender);
        return credit;
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    event SubmitOracleResponse(
        uint8 indexes,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    function triggerOracleResponse(
        uint8 indexes,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    ) external {
        emit SubmitOracleResponse(
            indexes,
            airline,
            flight,
            timestamp,
            statusCode
        );
    }

// endregion

}

// FlightSuretyData.sol interface
contract FlightSuretyData {
    function multiCallsLength() external returns (uint256);

    //----------------- Set and Get function for Airline struct ------------------------------
    function getAirlineOperatingStatus(address account) external returns (bool);

    function setAirlineOperatingStatus(address account, bool status) external;

    function getAirlineRegistrationStatus(address account) external returns (bool);

    function getVoteCounter(address account) external returns (uint256);

    function setVoteCounter(address account, uint256 vote) external;

    function getVoterStatus(address voter) external returns (bool);

    function resetVoteCounter(address account) external;

    function addVoters(address voter) external;

    function addVoterCounter(address airline, uint256 count) external;

    // ---------------------------- Insurance registration --------------------------
    function buy(address airline, address passenger, uint256 amount) external;

    function creditInsurees(address airline, address passenger, uint256 amount) external;

    function getInsuredPassenger_amount(address airline) external returns (address, uint256);

    function getPassengerCredit(address passenger) external returns (uint256);

    //-----------------------------Fund recording -------------------------
    function fund(address airline, uint256 amount) external;

    function getAirlineFunding(address airline) external returns (uint256);

    function registerAirline(address account, bool isOperational) external;

    function withdraw(address passenger) external returns (uint256);
}
