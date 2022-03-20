
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeContract(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  /****************************************************************************************/
  /* Airlines tests                                                             */
  /****************************************************************************************/

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(multiparty) test multi party when threshold is reached', async () => {

    // ARRANGE
    let flight1 = accounts[1];
    let flight2 = accounts[2];
    let flight3 = accounts[3];
    let flight4 = accounts[4];


    try {
        await config.flightSuretyApp.registerAirline(flight1, { from: config.owner });
        await config.flightSuretyApp.registerAirline(flight2, { from: config.owner });
        await config.flightSuretyApp.registerAirline(flight3, { from: config.owner });
        await config.flightSuretyApp.registerAirline(flight4, { from: config.owner });


    } catch (e) {
        console.log('flight registration failed with: ' + e);
    }

    let result = await config.flightSuretyData.isAirline.call(flight4);

    // ASSERT
    assert.equal(result, false, "Multi party call success");
});

it('(airline)ariline requires minimum funding of 10 ether to be operational', async () => {

    // ARRANGE
    let flight1 = accounts[2];
    let flight2 = accounts[3];
    let fundAmount = web3.utils.toWei("10", "ether");

    try {
        await config.flightSuretyApp.fund({ from: flight1, value: fundAmount });
        await config.flightSuretyApp.fund({ from: flight2, value: fundAmount });

    } catch (e) {
    }

    let result = await config.flightSuretyData.getAirlineOperatingStatus.call(flight2);

    // ASSERT
    assert.equal(result, true, "Status is not true")

});

it('(multiparty)test Voting when multi party threshold is reached', async () => {

    // ARRANGE

    let flight2 = accounts[2];
    let flight3 = accounts[3];
    let flight4 = accounts[4];


    try {
        let registrationStatus = await config.flightSuretyApp.registerAirline.call(flight4, { from: flight3 });

        if (registrationStatus[0] == false && registrationStatus[1] == false) {
            await config.flightSuretyApp.approveAirlineRegistration(flight4, true, { from: config.owner });  
            await config.flightSuretyApp.approveAirlineRegistration(flight4, true, { from: flight3 });         
            await config.flightSuretyApp.approveAirlineRegistration(flight4, false, { from: flight2 });
        }
        await config.flightSuretyApp.registerAirline(flight4, { from: flight3 });
    } catch (e) {
        console.log("registring vote has failed: " + e)
    }

    let result = await config.flightSuretyData.isAirline.call(flight4);

    // ASSERT
    assert.equal(result, false, "Multi party voting call failed");
});

it('(airline)Passenger can buy flight insurance for at most 1 ether', async () => {

    // ARRANGE
    let passenger6 = accounts[6];
    let flight2 = accounts[2];
    let rawAmount = 1;
    let InsuredPrice = web3.utils.toWei(rawAmount.toString(), "ether");

    try {
        await config.flightSuretyApp.buy(flight2, { from: passenger6, value: InsuredPrice });
    } catch (e) {
        console.log('Cannot buy insurance: ' + e)
    }
    let result = await config.flightSuretyData.getInsuredPassenger_amount.call(flight2);

    // ASSERT
    assert.equal(result[0], passenger6, "Status is not true")
});

it('(airline)Insured passenger must be credited if flight is delayed', async () => {

    // ARRANGE
    // let passenger = accounts[10];
    // let airline = accounts[2];
    let passenger = accounts[6];
    let airline = accounts[2];
    let creditStatus = true;
    let beforeCredit = 0
    let afterCredit = 0
    let STATUS_CODE_LATE_AIRLINE = 20;
    let flight = 'AS1234';
    let timestamp = Math.floor(Date.now() / 1000);

    try {
        beforeCredit = await config.flightSuretyApp.getPassengerCreditedAmount.call({ from: passenger });
        beforeCredit = web3.utils.fromWei(beforeCredit, "ether")
        await config.flightSuretyApp.processFlightStatus(airline, flight, timestamp, STATUS_CODE_LATE_AIRLINE);
        afterCredit = await config.flightSuretyApp.getPassengerCreditedAmount.call({ from: passenger });
        afterCredit = web3.utils.fromWei(afterCredit, "ether");
    } catch (e) {
        console.log("passenger could not be credited:" + e)
        creditStatus = false;
    }

    // ASSERT
    assert.equal(1.5, afterCredit, "balance credited is incorect")
    assert.equal(creditStatus, true, "Passenger is not credited");
});

it('(airline)Credited passenger can withdraw ether', async () => {

    // ARRANGE
    // let passenger = accounts[10];
    let passenger = accounts[6];
    let withdraw = true;
    let beforeCredit = 0;
    let afterCredit = 0;
    let ethBeforeCredit = 0;
    let ethAfterCredit = 0;
    try {
        beforeCredit = await config.flightSuretyApp.getPassengerCreditedAmount.call({ from: passenger })
        beforeCredit = web3.utils.fromWei(beforeCredit, "ether");
        ethBeforeCredit = await web3.eth.getBalance(passenger)
        ethBeforeCredit = web3.utils.fromWei(ethBeforeCredit, "ether");

        await config.flightSuretyApp.pay({ from: passenger });
        afterCredit = await config.flightSuretyApp.getPassengerCreditedAmount.call({ from: passenger })
        afterCredit = web3.utils.fromWei(afterCredit, "ether");

        ethAfterCredit = await web3.eth.getBalance(passenger)
        ethAfterCredit = web3.utils.fromWei(ethAfterCredit, "ether");
    } catch (e) {
        withdraw = false;
    }

    // ASSERT
    assert.equal(withdraw, true, "Passenger could not withdraw");
    assert.equal(afterCredit, 0, "Credit was nott redrawn");
});


});
