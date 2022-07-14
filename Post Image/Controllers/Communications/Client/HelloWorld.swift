/*
 * Copyright 2019, gRPC Authors All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#if compiler(>=5.6)
import Foundation
//import ArgumentParser
import GRPC
//import HelloWorldModel
import NIOCore
import NIOPosix

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
struct HelloWorld {
    //  @Option(help: "The port to connect to")
    var port: Int = 9090
    
    //  @Argument(help: "The name to greet")
    var name: Data
    
    func run(viewController: ViewController) async throws {
        // Setup an `EventLoopGroup` for the connection to run on.
        //
        // See: https://github.com/apple/swift-nio#eventloops-and-eventloopgroups
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // Make sure the group is shutdown when we're done with it.
        defer {
            try! group.syncShutdownGracefully()
        }
        
        // Configure the channel, we're not using TLS so the connection is `insecure`.
        let channel = try GRPCChannelPool.with(
            target: .host("[server uri]", port: self.port),
            transportSecurity: .plaintext,
            eventLoopGroup: group
        )
        
        
        // Close the connection when we're done with it.
        defer {
            try! channel.close().wait()
        }
        
        // Provide the connection to the generated client.
        let greeter = GreeterAsyncClient(channel: channel)
        //        let anyService = GRPCAnyServiceClient(channel: channel)
        
        //        let sayHello = anyService.makeUnaryCall(
        //            path: "/helloworld.Simple/SayHello",
        //            request: Helloworld_HelloRequest.with {
        //                $0.name = "gRPC Swift user"
        //            },
        //            responseType: Helloworld_HelloReply.self
        //        )
        
        //        debugPrint(sayHello)
        //        print(sayHello.response)
        //        print(sayHello.status)
        //
        //        print( try sayHello.response.map { $0.message }.wait() )
        // Form the request with the name, if one was provided.
        let request = HelloRequest.with {
            $0.name = self.name
        }
        let numTrial = await viewController.numTrial
        
        for _ in 1...numTrial {
            
            do {
                await viewController.startTick()
                let greeting = try await greeter.sayHello(request)
                print("Greeter received: \(greeting.message)")
//                await viewController.view.makeToast("Greeter received: \(greeting.message)")
                await viewController.endTick()
                
            } catch {
                print("Greeter failed: \(error)")
            }
        }
        await viewController.showResult()
        

    }
}
#endif // compiler(>=5.6)
