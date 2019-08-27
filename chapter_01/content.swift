i// Chapter 1
// Metal by Tutorials
// By Caroline Begbie & Marius Horga.

import PlaygroundSupport
import MetalKit

// Check for suitable GPU by creating a device
guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("GPU is not supported")
}

// Create a Rect
let frame = CGRect(x: 0, y: 0, width: 600, height: 600)
// Create a MTKView
let view = MTKView(frame: frame, device: device)
// Set the clearColor to a color
view.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1)

// The allocator manages the memory for the mesh data
let allocator = MTKMeshBufferAllocator(device: device)
// Creates a sphere
let mdlMesh = MDLMesh(sphereWithExtent: [0.2, 0.75, 0.2],
                      segments: [100, 100],
                      inwardNormals: false,
                      geometryType: .triangles,
                      allocator: allocator)
// Convert from Model I/O mesh to MetalKit mesh
let mesh = try MTKMesh(mesh: mdlMesh, device: device)

// Make the Command Queue from the device
guard let commandQueue = device.makeCommandQueue() else {
    fatalError("Could not create a command queue")
}

// Shaders
let shader = """

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
float4 position [[ attribute(0) ]];
};

vertex float4 vertex_main(const VertexIn vertex_in [[ stage_in ]]) {
return vertex_in.position;
}

fragment float4 fragment_main() {
return float4(1, 0, 0, 1);
}

"""

// Shader Library
let library = try device.makeLibrary(source: shader, options: nil)
// Get the vertex function
let vertexFunction = library.makeFunction(name: "vertex_main")
// Get the fragment function
let fragmentFunction = library.makeFunction(name: "fragment_main")

// Create a descriptor to set up the pipeline state
let descriptor = MTLRenderPipelineDescriptor()
// Set the color pixel format
descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
// Pass in the vertex function
descriptor.vertexFunction = vertexFunction
// Pass in the fragment function
descriptor.fragmentFunction = fragmentFunction
// Set up the vertex descriptor
//      - Use the MTKMesh's vertexDescriptor
descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

// Create the pipeline state for the descriptor
let pipelineState =
    try device.makeRenderPipelineState(descriptor: descriptor)


// Create the command buffer
//      - This stores all the commands that you'll ask the GPU to run.
guard let commandBuffer = commandQueue.makeCommandBuffer(),
    // Get the current render descriptor
    //      - The descriptor holds data for a number of render destinations, called "attachments". Each attachment will need information such as a texture to store to, and whether to keep the texture throughout the render pass.
    let descriptor = view.currentRenderPassDescriptor,
    // Create a render command encoder from the command buffer and descriptor
    //      - This holds all the information necessary to send to the GPU so that the GPU can draw the vertices.
    let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
        fatalError()
        
}

// Give the render encoder the pipeline state
renderEncoder.setRenderPipelineState(pipelineState)

// Pass the vertex buffer data from the MTKMesh
renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)

// Grab the first (and only) submesh for this mesh
guard let submesh = mesh.submeshes.first else {
    fatalError()
}

// Instruct the GPU to draw a primitive
renderEncoder.drawIndexedPrimitives(type: .triangle,
                                    indexCount: submesh.indexCount,
                                    indexType: submesh.indexType,
                                    indexBuffer: submesh.indexBuffer.buffer,
                                    indexBufferOffset: 0)

// Tell the render encoder that there are no more draw calls
renderEncoder.endEncoding()

// Get a drawable from the view
//      - The MTKView is backed by a Core Animation CAMetalLayer and the layer owns a drawable texture which Metal can read and write to.
guard let drawable = view.currentDrawable else {
    fatalError()
}

// Ask the command buffer to present the view's drawable
commandBuffer.present(drawable)
// Commit to the GPU
commandBuffer.commit()

PlaygroundPage.current.liveView = view

