#include <hip/hip_runtime.h>
#include <hip/device_functions.h>
#include <hip/hip_ext.h>
#include <hip/math_functions.h>
#include <hip/hip_fp8.h>
#include <algorithm>
#include <cassert>
#include <chrono>
#include <iostream>
#include <limits>
#include <string>
#include <numeric>
#include <cstdint>
#include <cstring>
#include "KernelArguments.hpp"
#include "cblas.h"

template<typename Ti, typename To>
hipError_t launchASMCopy(hipFunction_t func, To *out, Ti* in, std::uint32_t length) {

    std::uint32_t workgroups = 1;

    KernelArguments args;
    args.append(out);
    args.append(in);
    args.append(length);
    args.applyAlignment();

    std::size_t argsSize = args.size();
    void *launchArgs[] = {
        HIP_LAUNCH_PARAM_BUFFER_POINTER,
        args.buffer(),
        HIP_LAUNCH_PARAM_BUFFER_SIZE,
        &argsSize,
        HIP_LAUNCH_PARAM_END
    };

    hipStream_t stream{};
    auto err = hipStreamCreate(&stream);

    err = hipExtModuleLaunchKernel(func, 64 * workgroups, 1, 1, 64, 1, 1, 1000 * sizeof(float), nullptr, nullptr, launchArgs);

    err = hipStreamSynchronize(stream);

    err = hipStreamDestroy(stream);
    
    return err;
}


hipError_t prepareASMKernel(const std::string &funcName, const std::string &coPath, hipModule_t *module, hipFunction_t *func) {
    auto err = hipModuleLoad(module, coPath.c_str());
    if (err != hipSuccess)
        std::cout << "hipModuleLoad failed" << std::endl;
    err = hipModuleGetFunction(func, *module, funcName.c_str());
    if (err != hipSuccess)
        std::cout << "hipModuleGetFunction failed" << std::endl;
    return err;
}

template <typename T>
void Sample(const std::string& coPath, const std::uint32_t& length)
{
    hipDevice_t dev{};
    auto err = hipDeviceGet(&dev, 0);

    std::vector<T> cpuRef(length);
    std::vector<T> cpuOutput(length);
    std::vector<T> cpuInput(length);
    for(int i=0; i<length; i++)
        cpuInput[i] = T(i+1);

    std::memcpy(cpuRef.data(), cpuInput.data(), cpuInput.size() * sizeof(T));

    for (std::size_t i = 0; i < length; ++i) {
        std::cout << "Tony Ref " << float(cpuInput[i]) << std::endl;
    }

    T *gpuOutput{};
    err = hipMalloc(&gpuOutput, sizeof(T) * length);
    err = hipMemset(gpuOutput, 0, sizeof(T) * length);

    T *gpuInput{};
    err = hipMalloc(&gpuInput, sizeof(T) * length);
    err = hipMemcpyHtoD(gpuInput, cpuInput.data(), sizeof(T) * length);

    hipModule_t module{};
    hipFunction_t func{};

    err = prepareASMKernel("Copy", coPath, &module, &func);
    if (err)
        std::cout << "find asm kernel failed" << std::endl;

    err = launchASMCopy(func, gpuOutput, gpuInput, length);
    if (err)
        std::cout << "launchASMCopy error : " << err << std::endl;

    err = hipMemcpyDtoH(cpuOutput.data(), gpuOutput, cpuInput.size() * sizeof(T));

    for (std::size_t i = 0; i < length; ++i) {
        std::cout << "Tony GPU " << float(cpuOutput[i]) << std::endl;
    }

    err = hipFree(gpuOutput);
    err = hipFree(gpuInput);
    err = hipModuleUnload(module);
}

int main(int argc, char **argv) {

    if (argc != 2)
    {
        std::cout << "./copy [length]" << std::endl;
        return -1;
    }

    const std::uint32_t length(std::atoi(argv[1]));

    Sample<__hip_fp8_e4m3_fnuz>("copy.co", length);

    std::cout << "Tony sizeof __hip_fp8_e4m3_fnuz " << sizeof(__hip_fp8_e4m3_fnuz) << std::endl;

    return 0;
}
