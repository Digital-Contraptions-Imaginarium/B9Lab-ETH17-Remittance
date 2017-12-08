#!/bin/bash

echo "Creates Alice's, Bob's and Carol's wallets. Alice's is initialized with 10 eth, while Carol's"
echo "with 1, to be able to pay for the gas to deploy the contract in the first place."
testrpc \
    --account="0x7c07c0561b2a9d366149946af214d468ef6bb5e4ac68fd5840c5f801b26c1995,10000000000000000000" \
    --account="0x463eb9b2a7e356b447cb856baed15b37d116594b883c69eef73154c01b2f2a8a,0" \
    --account="0x7667b07529bd46842fff3e4102e7d3176a88fbe8ae139ad42c442c761753a3ca,1000000000000000000"
