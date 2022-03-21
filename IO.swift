protocol World {}

typealias IO<T> = (World) -> (T, World)

precedencegroup MyPrecedenceGroup {
    associativity: left
}
infix operator ==>: MyPrecedenceGroup
infix operator -->: MyPrecedenceGroup


// then
func ==><T, U>(_ lhs: @escaping IO<T>, _ rhs: @escaping IO<U>) -> IO<U> {
    return { world1 in
        let (_, world2) = lhs(world1)
        return rhs(world2)
    }
}

// map
func --><T, U>(_ lhs: @escaping IO<T>, _ rhs: @escaping (T) -> U) -> IO<U> {
    return { world1 in
        let (t, world2) = lhs(world1)
        let u = rhs(t)
        return (u, world2)
    }
}

// flatmap
func --><T, U>(_ lhs: @escaping IO<T>, _ rhs: @escaping (T) -> IO<U>) -> IO<U> {
    return { world1 in
        let (t, world2) = lhs(world1)
        return rhs(t)(world2)
    }
}

func liftIO<T>(_ f: @escaping () -> T) -> IO<T> {
    return { world in
        (f(), world)
    }
}

func doWhileIO<T>(_ f: @escaping IO<T>, _ condition: @escaping (T) -> Bool) -> IO<T> {
    return f --> { t in
        if condition(t) {
            return doWhileIO(f, condition)
        } else {
            return liftIO { t }
        }
    }
}

func readLn() -> IO<String?> {
    liftIO { readLine() }
}

func printLn(_ string: String) -> IO<Void> {
    liftIO { print(string) }
}

func readInt() -> IO<Int?> {
    readLn() --> { $0.flatMap(Int.init) }
}

func liftOptionalF<T, U>(_ f: @escaping (T) -> U) -> (T?) -> U? {
    return { 
        return $0.map(f)
    }
}

func onNil<T, U>(_ f: @escaping (T?) -> U?, _ value: U) -> (T?) -> U {
    return {
        f($0) ?? value
    }
}

extension Optional {
    var hasValue: Bool {
        self == nil
    }
}

extension Int {
    var isLessThanOne: Bool {
        self < 1
    }
}

// Creates a free function from an instance method with no parameters.
func freeF<T, U>(_ f: @escaping (T) -> () -> U) -> (T) -> U {
    return { f($0)() }
}

// Creates a free function from a KeyPath.
func freeF<T, U>(_ path: KeyPath<T, U>) -> (T) -> U {
    return { $0[keyPath: path] }
}

let isNilOrEmptyString = onNil(liftOptionalF(freeF(\String.isEmpty)), true)
let isNilOrLessThanOne = onNil(liftOptionalF(freeF(\Int.isLessThanOne)), true)

func main() -> IO<Void> {
    doWhileIO(
        printLn("What is your name?") ==> readLn(),
        isNilOrEmptyString
    ) --> { name in 
        printLn("Welcome, \(name!)!")
    } ==> doWhileIO(
        printLn("What would you like to buy?") ==> readLn(),
        isNilOrEmptyString
    ) --> { item in
        doWhileIO(
            printLn("How many \(item!)?") ==> readInt(), 
            isNilOrLessThanOne
        ) --> { num in 
           (item, num)
        }
    } --> { (item, num) in
        if num == 1 {
            return printLn("Here is a \(item!)!")
        }
        return printLn("Here are \(num!) \(item!)!")
    }
}

struct DummyWorld: World {}
let world1 = DummyWorld()
let world2 = main()(world1).1


// -- Second iteration -- 
// func main1() -> IO<Void> {
//     printLn("Hi, what's your name") ==>
//     readLn() --> { name in
//         printLn("Welcome, \(name), what would you like to buy?") ==>
//         readLn() --> { item in
//             printLn("How many \(item) would you like?") ==>
//             readInt() --> { (num) in
//                 printLn("These are my last \(num!) \(item)!")
//             }
//         }
//     }
// }

// -- First iteration -- 
// func main() -> IO {
//     return { world1 in 
//         let world2 = printLn("What is your name?")(world1)
//         let (name, world3) = readLn()(world2)
//         return printLn("Hello, \(name)")(world3)
//     }
// }

// func readLn(world: World) -> (String, World) {
//     let str = readLine() ?? ""
//     return (str, world)
// }

// func printLn(world: World, string: String) -> World {
//     print(string)
//     return world
// }

// func main(world: World) -> World {
//     let world2 = printLn(world: world, string: "What is your name?")
//     let (name, world3) = readLn(world: world2)
//     return printLn(world: world3, string: "Hello, \(name)")
// }