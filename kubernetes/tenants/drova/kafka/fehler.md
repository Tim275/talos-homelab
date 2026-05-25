# fehler.md — drova-kafka

## strimzi-upgrade auf 0.51

strimzi auto-upgrade auf 0.51 lief durch (renovate). kafka 4.0.0 hat 0.51 nicht mehr supported.

## dual-role pods deadlock

dual-role pods (controller+broker in einem pod, 3 stück) sind bei strimzi 0.51 + kafka 4.1.1 ein problem-fall. die brokers im pod warten auf den controller im selben pod, der wartet auf quorum mit den anderen, die machen das gleiche → deadlock.

**fix:** KafkaNodePool gesplittet. einen `controller`-pool mit 3 dedicated pods (klein, 2gi storage), einen `broker`-pool mit 3 dedicated pods (10gi). nicht mehr dual-role. das ist sowieso strimzi production-best-practice, hätt ich von anfang an so haben sollen.
