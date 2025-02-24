(******************************************************************************
 *                                 PasVulkan                                  *
 ******************************************************************************
 *                       Version see PasVulkan.Framework.pas                  *
 ******************************************************************************
 *                                zlib license                                *
 *============================================================================*
 *                                                                            *
 * Copyright (C) 2016-2020, Benjamin Rosseaux (benjamin@rosseaux.de)          *
 *                                                                            *
 * This software is provided 'as-is', without any express or implied          *
 * warranty. In no event will the authors be held liable for any damages      *
 * arising from the use of this software.                                     *
 *                                                                            *
 * Permission is granted to anyone to use this software for any purpose,      *
 * including commercial applications, and to alter it and redistribute it     *
 * freely, subject to the following restrictions:                             *
 *                                                                            *
 * 1. The origin of this software must not be misrepresented; you must not    *
 *    claim that you wrote the original software. If you use this software    *
 *    in a product, an acknowledgement in the product documentation would be  *
 *    appreciated but is not required.                                        *
 * 2. Altered source versions must be plainly marked as such, and must not be *
 *    misrepresented as being the original software.                          *
 * 3. This notice may not be removed or altered from any source distribution. *
 *                                                                            *
 ******************************************************************************
 *                  General guidelines for code contributors                  *
 *============================================================================*
 *                                                                            *
 * 1. Make sure you are legally allowed to make a contribution under the zlib *
 *    license.                                                                *
 * 2. The zlib license header goes at the top of each source file, with       *
 *    appropriate copyright notice.                                           *
 * 3. This PasVulkan wrapper may be used only with the PasVulkan-own Vulkan   *
 *    Pascal header.                                                          *
 * 4. After a pull request, check the status of your pull request on          *
      http://github.com/BeRo1985/pasvulkan                                    *
 * 5. Write code which's compatible with Delphi >= 2009 and FreePascal >=     *
 *    3.1.1                                                                   *
 * 6. Don't use Delphi-only, FreePascal-only or Lazarus-only libraries/units, *
 *    but if needed, make it out-ifdef-able.                                  *
 * 7. No use of third-party libraries/units as possible, but if needed, make  *
 *    it out-ifdef-able.                                                      *
 * 8. Try to use const when possible.                                         *
 * 9. Make sure to comment out writeln, used while debugging.                 *
 * 10. Make sure the code compiles on 32-bit and 64-bit platforms (x86-32,    *
 *     x86-64, ARM, ARM64, etc.).                                             *
 * 11. Make sure the code runs on all platforms with Vulkan support           *
 *                                                                            *
 ******************************************************************************)
unit PasVulkan.Scene3D.Renderer.SkyCubeMap;
{$i PasVulkan.inc}
{$ifndef fpc}
 {$ifdef conditionalexpressions}
  {$if CompilerVersion>=24.0}
   {$legacyifend on}
  {$ifend}
 {$endif}
{$endif}
{$m+}

interface

uses SysUtils,
     Classes,
     Math,
     Vulkan,
     PasVulkan.Types,
     PasVulkan.Math,
     PasVulkan.Framework,
     PasVulkan.Application,
     PasVulkan.Scene3D.Renderer.Globals;

type { TpvScene3DRendererSkyCubeMap }
     TpvScene3DRendererSkyCubeMap=class
      public
       const Width=512;
             Height=512;
      private
       fComputeShaderModule:TpvVulkanShaderModule;
       fVulkanPipelineShaderStageCompute:TpvVulkanPipelineShaderStage;
       fVulkanImage:TpvVulkanImage;
       fVulkanSampler:TpvVulkanSampler;
       fVulkanImageView:TpvVulkanImageView;
       fMemoryBlock:TpvVulkanDeviceMemoryBlock;
       fDescriptorImageInfo:TVkDescriptorImageInfo;
       fLightDirection:TpvVector3;
      public

       constructor Create(const aVulkanDevice:TpvVulkanDevice;const aVulkanPipelineCache:TpvVulkanPipelineCache;const aLightDirection:TpvVector3;const aImageFormat:TVkFormat=TVkFormat(VK_FORMAT_R16G16B16A16_SFLOAT));

       destructor Destroy; override;

      published

       property VulkanImage:TpvVulkanImage read fVulkanImage;

       property VulkanSampler:TpvVulkanSampler read fVulkanSampler;

       property VulkanImageView:TpvVulkanImageView read fVulkanImageView;

      public

       property DescriptorImageInfo:TVkDescriptorImageInfo read fDescriptorImageInfo;

       property LightDirection:TpvVector3 read fLightDirection;

     end;

implementation

{ TpvScene3DRendererSkyCubeMap }

constructor TpvScene3DRendererSkyCubeMap.Create(const aVulkanDevice:TpvVulkanDevice;const aVulkanPipelineCache:TpvVulkanPipelineCache;const aLightDirection:TpvVector3;const aImageFormat:TVkFormat);
var Index,FaceIndex,MipMaps:TpvSizeInt;
    Stream:TStream;
    MemoryRequirements:TVkMemoryRequirements;
    RequiresDedicatedAllocation,
    PrefersDedicatedAllocation:boolean;
    MemoryBlockFlags:TpvVulkanDeviceMemoryBlockFlags;
    ImageSubresourceRange:TVkImageSubresourceRange;
    GraphicsQueue:TpvVulkanQueue;
    GraphicsCommandPool:TpvVulkanCommandPool;
    GraphicsCommandBuffer:TpvVulkanCommandBuffer;
    GraphicsFence:TpvVulkanFence;
    ComputeQueue:TpvVulkanQueue;
    ComputeCommandPool:TpvVulkanCommandPool;
    ComputeCommandBuffer:TpvVulkanCommandBuffer;
    ComputeFence:TpvVulkanFence;
    ImageView:TpvVulkanImageView;
    DescriptorImageInfo:TVkDescriptorImageInfo;
    VulkanDescriptorSetLayout:TpvVulkanDescriptorSetLayout;
    VulkanDescriptorPool:TpvVulkanDescriptorPool;
    VulkanDescriptorSet:TpvVulkanDescriptorSet;
    FrameBuffer:TpvVulkanFrameBuffer;
    RenderPass:TpvVulkanRenderPass;
    FrameBufferColorAttachment:TpvVulkanFrameBufferAttachment;
    PipelineLayout:TpvVulkanPipelineLayout;
    Pipeline:TpvVulkanComputePipeline;
    ImageBlit:TVkImageBlit;
    ImageMemoryBarrier:TVkImageMemoryBarrier;
    LocalLightDirection:TpvVector4;
begin
 inherited Create;

 fLightDirection:=aLightDirection;

 LocalLightDirection:=TpvVector4.InlineableCreate(fLightDirection,0.0);

 MipMaps:=IntLog2(Max(Width,Height))+1;

 case pvApplication.VulkanDevice.PhysicalDevice.Properties.vendorID of
  TVkUInt32(TpvVulkanVendorID.NVIDIA),TVkUInt32(TpvVulkanVendorID.AMD):begin
   Stream:=pvScene3DShaderVirtualFileSystem.GetFile('cubemap_sky_comp.spv');
// Stream:=pvScene3DShaderVirtualFileSystem.GetFile('cubemap_sky_fast_comp.spv');
  end;
  else begin
   Stream:=pvScene3DShaderVirtualFileSystem.GetFile('cubemap_sky_fast_comp.spv');
  end;
 end;
 try
  fComputeShaderModule:=TpvVulkanShaderModule.Create(pvApplication.VulkanDevice,Stream);
 finally
  Stream.Free;
 end;

 fVulkanPipelineShaderStageCompute:=TpvVulkanPipelineShaderStage.Create(VK_SHADER_STAGE_COMPUTE_BIT,fComputeShaderModule,'main');

 fVulkanImage:=TpvVulkanImage.Create(pvApplication.VulkanDevice,
                                     TVkImageCreateFlags(VK_IMAGE_CREATE_CUBE_COMPATIBLE_BIT),
                                     VK_IMAGE_TYPE_2D,
                                     aImageFormat,
                                     Width,
                                     Height,
                                     1,
                                     MipMaps,
                                     6,
                                     VK_SAMPLE_COUNT_1_BIT,
                                     VK_IMAGE_TILING_OPTIMAL,
                                     TVkImageUsageFlags(VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT) or
                                     TVkImageUsageFlags(VK_IMAGE_USAGE_TRANSFER_SRC_BIT) or
                                     TVkImageUsageFlags(VK_IMAGE_USAGE_TRANSFER_DST_BIT) or
                                     TVkImageUsageFlags(VK_IMAGE_USAGE_STORAGE_BIT) or
                                     TVkImageUsageFlags(VK_IMAGE_USAGE_SAMPLED_BIT),
                                     VK_SHARING_MODE_EXCLUSIVE,
                                     0,
                                     nil,
                                     VK_IMAGE_LAYOUT_UNDEFINED
                                    );

 MemoryRequirements:=pvApplication.VulkanDevice.MemoryManager.GetImageMemoryRequirements(fVulkanImage.Handle,
                                                                                         RequiresDedicatedAllocation,
                                                                                         PrefersDedicatedAllocation);

 MemoryBlockFlags:=[];

 if RequiresDedicatedAllocation or PrefersDedicatedAllocation then begin
  Include(MemoryBlockFlags,TpvVulkanDeviceMemoryBlockFlag.DedicatedAllocation);
 end;

 fMemoryBlock:=pvApplication.VulkanDevice.MemoryManager.AllocateMemoryBlock(MemoryBlockFlags,
                                                                            MemoryRequirements.size,
                                                                            MemoryRequirements.alignment,
                                                                            MemoryRequirements.memoryTypeBits,
                                                                            TVkMemoryPropertyFlags(VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT),
                                                                            0,
                                                                            0,
                                                                            0,
                                                                            0,
                                                                            0,
                                                                            0,
                                                                            0,
                                                                            TpvVulkanDeviceMemoryAllocationType.ImageOptimal,
                                                                            @fVulkanImage.Handle);
 if not assigned(fMemoryBlock) then begin
  raise EpvVulkanMemoryAllocationException.Create('Memory for texture couldn''t be allocated!');
 end;

 fMemoryBlock.AssociatedObject:=self;

 VulkanCheckResult(pvApplication.VulkanDevice.Commands.BindImageMemory(pvApplication.VulkanDevice.Handle,
                                                                       fVulkanImage.Handle,
                                                                       fMemoryBlock.MemoryChunk.Handle,
                                                                       fMemoryBlock.Offset));

 GraphicsQueue:=pvApplication.VulkanDevice.GraphicsQueue;

 ComputeQueue:=pvApplication.VulkanDevice.ComputeQueue;

 GraphicsCommandPool:=TpvVulkanCommandPool.Create(pvApplication.VulkanDevice,
                                                  pvApplication.VulkanDevice.GraphicsQueueFamilyIndex,
                                                  TVkCommandPoolCreateFlags(VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT));
 try

  GraphicsCommandBuffer:=TpvVulkanCommandBuffer.Create(GraphicsCommandPool,VK_COMMAND_BUFFER_LEVEL_PRIMARY);
  try

   GraphicsFence:=TpvVulkanFence.Create(pvApplication.VulkanDevice);
   try

    ComputeCommandPool:=TpvVulkanCommandPool.Create(pvApplication.VulkanDevice,
                                                    pvApplication.VulkanDevice.ComputeQueueFamilyIndex,
                                                    TVkCommandPoolCreateFlags(VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT));
    try

     ComputeCommandBuffer:=TpvVulkanCommandBuffer.Create(ComputeCommandPool,VK_COMMAND_BUFFER_LEVEL_PRIMARY);
     try

      ComputeFence:=TpvVulkanFence.Create(pvApplication.VulkanDevice);
      try

       FillChar(ImageSubresourceRange,SizeOf(TVkImageSubresourceRange),#0);
       ImageSubresourceRange.aspectMask:=TVkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT);
       ImageSubresourceRange.baseMipLevel:=0;
       ImageSubresourceRange.levelCount:=MipMaps;
       ImageSubresourceRange.baseArrayLayer:=0;
       ImageSubresourceRange.layerCount:=6;

       fVulkanImage.SetLayout(TVkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT),
                              TVkImageLayout(VK_IMAGE_LAYOUT_UNDEFINED),
                              TVkImageLayout(VK_IMAGE_LAYOUT_GENERAL),
                              @ImageSubresourceRange,
                              GraphicsCommandBuffer,
                              GraphicsQueue,
                              GraphicsFence,
                              true);

       fVulkanSampler:=TpvVulkanSampler.Create(pvApplication.VulkanDevice,
                                               TVkFilter(VK_FILTER_LINEAR),
                                               TVkFilter(VK_FILTER_LINEAR),
                                               TVkSamplerMipmapMode(VK_SAMPLER_MIPMAP_MODE_LINEAR),
                                               TVkSamplerAddressMode(VK_SAMPLER_ADDRESS_MODE_REPEAT),
                                               TVkSamplerAddressMode(VK_SAMPLER_ADDRESS_MODE_REPEAT),
                                               TVkSamplerAddressMode(VK_SAMPLER_ADDRESS_MODE_REPEAT),
                                               0.0,
                                               false,
                                               1.0,
                                               false,
                                               TVkCompareOp(VK_COMPARE_OP_NEVER),
                                               0.0,
                                               MipMaps,
                                               TVkBorderColor(VK_BORDER_COLOR_FLOAT_OPAQUE_BLACK),
                                               false);

       fVulkanImageView:=TpvVulkanImageView.Create(pvApplication.VulkanDevice,
                                                   fVulkanImage,
                                                   TVkImageViewType(VK_IMAGE_VIEW_TYPE_CUBE),
                                                   aImageFormat,
                                                   TVkComponentSwizzle(VK_COMPONENT_SWIZZLE_IDENTITY),
                                                   TVkComponentSwizzle(VK_COMPONENT_SWIZZLE_IDENTITY),
                                                   TVkComponentSwizzle(VK_COMPONENT_SWIZZLE_IDENTITY),
                                                   TVkComponentSwizzle(VK_COMPONENT_SWIZZLE_IDENTITY),
                                                   TVkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT),
                                                   0,
                                                   MipMaps,
                                                   0,
                                                   6);

       fDescriptorImageInfo:=TVkDescriptorImageInfo.Create(fVulkanSampler.Handle,
                                                           fVulkanImageView.Handle,
                                                           VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);

       ImageView:=TpvVulkanImageView.Create(pvApplication.VulkanDevice,
                                            fVulkanImage,
                                            TVkImageViewType(VK_IMAGE_VIEW_TYPE_CUBE),
                                            aImageFormat,
                                            TVkComponentSwizzle(VK_COMPONENT_SWIZZLE_IDENTITY),
                                            TVkComponentSwizzle(VK_COMPONENT_SWIZZLE_IDENTITY),
                                            TVkComponentSwizzle(VK_COMPONENT_SWIZZLE_IDENTITY),
                                            TVkComponentSwizzle(VK_COMPONENT_SWIZZLE_IDENTITY),
                                            TVkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT),
                                            0,
                                            1,
                                            0,
                                            6);
       try

        DescriptorImageInfo:=TVkDescriptorImageInfo.Create(fVulkanSampler.Handle,
                                                           ImageView.Handle,
                                                           VK_IMAGE_LAYOUT_GENERAL);
        try

         VulkanDescriptorSetLayout:=TpvVulkanDescriptorSetLayout.Create(pvApplication.VulkanDevice);
         try
          VulkanDescriptorSetLayout.AddBinding(0,
                                               VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
                                               1,
                                               TVkShaderStageFlags(VK_SHADER_STAGE_COMPUTE_BIT),
                                               []);
          VulkanDescriptorSetLayout.Initialize;

          VulkanDescriptorPool:=TpvVulkanDescriptorPool.Create(pvApplication.VulkanDevice,
                                                               TVkDescriptorPoolCreateFlags(VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT),
                                                               1);
          try

           VulkanDescriptorPool.AddDescriptorPoolSize(VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,1);
           VulkanDescriptorPool.Initialize;

           VulkanDescriptorSet:=TpvVulkanDescriptorSet.Create(VulkanDescriptorPool,
                                                              VulkanDescriptorSetLayout);
           try

            VulkanDescriptorSet.WriteToDescriptorSet(0,
                                                     0,
                                                     1,
                                                     TVkDescriptorType(VK_DESCRIPTOR_TYPE_STORAGE_IMAGE),
                                                     [DescriptorImageInfo],
                                                     [],
                                                     [],
                                                     false);
            VulkanDescriptorSet.Flush;

            PipelineLayout:=TpvVulkanPipelineLayout.Create(pvApplication.VulkanDevice);
            try
             PipelineLayout.AddPushConstantRange(TVkShaderStageFlags(VK_SHADER_STAGE_COMPUTE_BIT),0,SizeOf(TpvVector4));
             PipelineLayout.AddDescriptorSetLayout(VulkanDescriptorSetLayout);
             PipelineLayout.Initialize;

             Pipeline:=TpvVulkanComputePipeline.Create(pvApplication.VulkanDevice,
                                                       pvApplication.VulkanPipelineCache,
                                                       0,
                                                       fVulkanPipelineShaderStageCompute,
                                                       PipelineLayout,
                                                       nil,
                                                       0);
             try

              ComputeCommandBuffer.Reset(TVkCommandBufferResetFlags(VK_COMMAND_BUFFER_RESET_RELEASE_RESOURCES_BIT));

              ComputeCommandBuffer.BeginRecording(TVkCommandBufferUsageFlags(VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT));

 {            FillChar(ImageMemoryBarrier,SizeOf(TVkImageMemoryBarrier),#0);
              ImageMemoryBarrier.sType:=VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
              ImageMemoryBarrier.pNext:=nil;
              ImageMemoryBarrier.srcAccessMask:=TVkAccessFlags(VK_ACCESS_SHADER_READ_BIT);
              ImageMemoryBarrier.dstAccessMask:=TVkAccessFlags(VK_ACCESS_SHADER_WRITE_BIT);
              ImageMemoryBarrier.oldLayout:=VK_IMAGE_LAYOUT_GENERAL;
              ImageMemoryBarrier.newLayout:=VK_IMAGE_LAYOUT_GENERAL;
              ImageMemoryBarrier.srcQueueFamilyIndex:=VK_QUEUE_FAMILY_IGNORED;
              ImageMemoryBarrier.dstQueueFamilyIndex:=VK_QUEUE_FAMILY_IGNORED;
              ImageMemoryBarrier.image:=fVulkanImage.Handle;
              ImageMemoryBarrier.subresourceRange.aspectMask:=TVkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT);
              ImageMemoryBarrier.subresourceRange.baseMipLevel:=0;
              ImageMemoryBarrier.subresourceRange.levelCount:=MipMaps;
              ImageMemoryBarrier.subresourceRange.baseArrayLayer:=0;
              ImageMemoryBarrier.subresourceRange.layerCount:=1;
              ComputeCommandBuffer.CmdPipelineBarrier(TVkPipelineStageFlags(VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT),
                                                      TVkPipelineStageFlags(VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT),
                                                      0,
                                                      0,nil,
                                                      0,nil,
                                                      1,@ImageMemoryBarrier);
 }
              ComputeCommandBuffer.CmdBindPipeline(VK_PIPELINE_BIND_POINT_COMPUTE,Pipeline.Handle);

              ComputeCommandBuffer.CmdBindDescriptorSets(VK_PIPELINE_BIND_POINT_COMPUTE,
                                                         PipelineLayout.Handle,
                                                         0,
                                                         1,
                                                         @VulkanDescriptorSet.Handle,
                                                         0,
                                                         nil);

              ComputeCommandBuffer.CmdPushConstants(PipelineLayout.Handle,
                                                    TVkShaderStageFlags(TVkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT),
                                                    0,
                                                    SizeOf(TpvVector4),
                                                    @LocalLightDirection);

              ComputeCommandBuffer.CmdDispatch(Max(1,(Width+((1 shl 4)-1)) shr 4),
                                               Max(1,(Height+((1 shl 4)-1)) shr 4),
                                               6);

 {            FillChar(ImageMemoryBarrier,SizeOf(TVkImageMemoryBarrier),#0);
              ImageMemoryBarrier.sType:=VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
              ImageMemoryBarrier.pNext:=nil;
              ImageMemoryBarrier.srcAccessMask:=TVkAccessFlags(VK_ACCESS_SHADER_WRITE_BIT);
              ImageMemoryBarrier.dstAccessMask:=TVkAccessFlags(VK_ACCESS_MEMORY_READ_BIT);
              ImageMemoryBarrier.oldLayout:=VK_IMAGE_LAYOUT_GENERAL;
              ImageMemoryBarrier.newLayout:=VK_IMAGE_LAYOUT_GENERAL;
              ImageMemoryBarrier.srcQueueFamilyIndex:=VK_QUEUE_FAMILY_IGNORED;
              ImageMemoryBarrier.dstQueueFamilyIndex:=VK_QUEUE_FAMILY_IGNORED;
              ImageMemoryBarrier.image:=fVulkanImage.Handle;
              ImageMemoryBarrier.subresourceRange.aspectMask:=TVkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT);
              ImageMemoryBarrier.subresourceRange.baseMipLevel:=0;
              ImageMemoryBarrier.subresourceRange.levelCount:=MipMaps;
              ImageMemoryBarrier.subresourceRange.baseArrayLayer:=0;
              ImageMemoryBarrier.subresourceRange.layerCount:=1;
              ComputeCommandBuffer.CmdPipelineBarrier(TVkPipelineStageFlags(VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT),
                                                      TVkPipelineStageFlags(VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT),
                                                      0,
                                                      0,nil,
                                                      0,nil,
                                                      1,@ImageMemoryBarrier); }

              ComputeCommandBuffer.EndRecording;

              ComputeCommandBuffer.Execute(ComputeQueue,TVkPipelineStageFlags(VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT),nil,nil,ComputeFence,true);

             finally
              FreeAndNil(Pipeline);
             end;

            finally
             FreeAndNil(PipelineLayout);
            end;

           finally
            FreeAndNil(VulkanDescriptorSet);
           end;

          finally
           FreeAndNil(VulkanDescriptorPool);
          end;

         finally
          FreeAndNil(VulkanDescriptorSetLayout);
         end;

        finally
        end;

       finally
        FreeAndNil(ImageView);
       end;

      finally
       FreeAndNil(ComputeFence);
      end;

     finally
      FreeAndNil(ComputeCommandBuffer);
     end;

    finally
     FreeAndNil(ComputeCommandPool);
    end;

    // Generate mipmaps
    if true then begin

     fVulkanImage.SetLayout(TVkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT),
                            TVkImageLayout(VK_IMAGE_LAYOUT_GENERAL),
                            TVkImageLayout(VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL),
                            @ImageSubresourceRange,
                            GraphicsCommandBuffer,
                            GraphicsQueue,
                            GraphicsFence,
                            true);

     ImageMemoryBarrier:=TVkImageMemoryBarrier.Create(0,
                                                      0,
                                                      VK_IMAGE_LAYOUT_UNDEFINED,
                                                      VK_IMAGE_LAYOUT_UNDEFINED,
                                                      TVkQueue(VK_QUEUE_FAMILY_IGNORED),
                                                      TVkQueue(VK_QUEUE_FAMILY_IGNORED),
                                                      fVulkanImage.Handle,
                                                      ImageSubresourceRange);

     GraphicsCommandBuffer.Reset(TVkCommandBufferResetFlags(VK_COMMAND_BUFFER_RESET_RELEASE_RESOURCES_BIT));
     GraphicsCommandBuffer.BeginRecording(TVkCommandBufferUsageFlags(VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT));
     for Index:=1 to MipMaps-1 do begin

      ImageMemoryBarrier.subresourceRange.levelCount:=1;
      ImageMemoryBarrier.subresourceRange.baseMipLevel:=Index-1;
      ImageMemoryBarrier.oldLayout:=VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
      ImageMemoryBarrier.newLayout:=VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
      ImageMemoryBarrier.srcAccessMask:=TVkAccessFlags(VK_ACCESS_TRANSFER_WRITE_BIT);
      ImageMemoryBarrier.dstAccessMask:=TVkAccessFlags(VK_ACCESS_TRANSFER_READ_BIT);
      GraphicsCommandBuffer.CmdPipelineBarrier(TVkPipelineStageFlags(VK_PIPELINE_STAGE_TRANSFER_BIT),
                                               TVkPipelineStageFlags(VK_PIPELINE_STAGE_TRANSFER_BIT),
                                               0,
                                               0,
                                               nil,
                                               0,
                                               nil,
                                               1,
                                               @ImageMemoryBarrier);

      for FaceIndex:=0 to 5 do begin
       ImageBlit:=TVkImageBlit.Create(TVkImageSubresourceLayers.Create(TVkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT),
                                                                       Index-1,
                                                                       FaceIndex,
                                                                       1),
                                      [TVkOffset3D.Create(0,
                                                          0,
                                                          0),
                                       TVkOffset3D.Create(Width shr (Index-1),
                                                          Height shr (Index-1),
                                                          1)],
                                      TVkImageSubresourceLayers.Create(TVkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT),
                                                                       Index,
                                                                       FaceIndex,
                                                                       1),
                                      [TVkOffset3D.Create(0,
                                                          0,
                                                          0),
                                       TVkOffset3D.Create(Width shr Index,
                                                          Height shr Index,
                                                          1)]
                                     );

       GraphicsCommandBuffer.CmdBlitImage(fVulkanImage.Handle,VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                                          fVulkanImage.Handle,VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                                          1,
                                          @ImageBlit,
                                          TVkFilter(VK_FILTER_LINEAR));
      end;

      ImageMemoryBarrier.oldLayout:=VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
      ImageMemoryBarrier.newLayout:=VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
      ImageMemoryBarrier.srcAccessMask:=TVkAccessFlags(VK_ACCESS_TRANSFER_READ_BIT);
      ImageMemoryBarrier.dstAccessMask:=TVkAccessFlags(VK_ACCESS_SHADER_READ_BIT);
      GraphicsCommandBuffer.CmdPipelineBarrier(TVkPipelineStageFlags(VK_PIPELINE_STAGE_TRANSFER_BIT),
                                               TVkPipelineStageFlags(VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT),
                                               0,
                                               0,
                                               nil,
                                               0,
                                               nil,
                                               1,
                                               @ImageMemoryBarrier);

     end;
     ImageMemoryBarrier.subresourceRange.baseMipLevel:=MipMaps-1;
     ImageMemoryBarrier.oldLayout:=VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
     ImageMemoryBarrier.newLayout:=VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
     ImageMemoryBarrier.srcAccessMask:=TVkAccessFlags(VK_ACCESS_TRANSFER_WRITE_BIT);
     ImageMemoryBarrier.dstAccessMask:=TVkAccessFlags(VK_ACCESS_SHADER_READ_BIT);
     GraphicsCommandBuffer.CmdPipelineBarrier(TVkPipelineStageFlags(VK_PIPELINE_STAGE_TRANSFER_BIT),
                                              TVkPipelineStageFlags(VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT),
                                              0,
                                              0,
                                              nil,
                                              0,
                                              nil,
                                              1,
                                              @ImageMemoryBarrier);
     GraphicsCommandBuffer.EndRecording;
     GraphicsCommandBuffer.Execute(GraphicsQueue,TVkPipelineStageFlags(VK_PIPELINE_STAGE_TRANSFER_BIT),nil,nil,GraphicsFence,true);

    end else begin

     fVulkanImage.SetLayout(TVkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT),
                            TVkImageLayout(VK_IMAGE_LAYOUT_GENERAL),
                            TVkImageLayout(VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL),
                            @ImageSubresourceRange,
                            GraphicsCommandBuffer,
                            GraphicsQueue,
                            GraphicsFence,
                            true);

    end;

   finally
    FreeAndNil(GraphicsFence);
   end;

  finally
   FreeAndNil(GraphicsCommandBuffer);
  end;

 finally
  FreeAndNil(GraphicsCommandPool);
 end;

end;

destructor TpvScene3DRendererSkyCubeMap.Destroy;
begin
 FreeAndNil(fMemoryBlock);
 FreeAndNil(fVulkanImageView);
 FreeAndNil(fVulkanSampler);
 FreeAndNil(fVulkanImage);
 FreeAndNil(fVulkanPipelineShaderStageCompute);
 FreeAndNil(fComputeShaderModule);
 inherited Destroy;
end;

end.
