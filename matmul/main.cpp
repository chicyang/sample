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
#include <random>
#include "KernelArguments.hpp"
#include "cblas.h"

template <typename T>
void dumpBuffer(const char* title, const std::vector<T>& data, int M, int N)
{
    std::cout << "----- " << title << " start -----" << std::endl;
    for (int n=0; n<N; n++)
    {
        for (int m=0 ; m<M; m++)
        {
            std::cout << float(data[m+n*M]) << " ";
        }
        std::cout << std::endl;
    }
    std::cout << "----- " << title << " end -------" << std::endl << std::endl;
}

template<typename T>
void initialization(std::vector<T>& data, int M, int N)
{
    static std::mt19937 seed(69069);

    for (int n=0; n<N; n++)
    {
        for (int m=0 ; m<M; m++)
        {
//            data[m+n*M] = T(1.0f);
            data[m+n*M] = T(float(std::uniform_int_distribution<unsigned>(1, 4)(seed)));
        }
    }
}

template <typename T>
void CPUMatMul(std::vector<float>& C, const std::vector<T>& A, const std::vector<T>& B, int M, int N, int K)
{
    for(int n=0; n<N; n++)
    {
        for(int m=0; m<M; m++)
        {
            for(int k=0; k<K; k++)
            {
                C[n*M+m] = C[n*M+m] + (float(A[m*K+k]) * float(B[n*K+k]));
            }
        }
    }
}

template<typename T>
hipError_t launchASMMatMul(hipFunction_t func, float* gpuC, T* gpuA, T* gpuB, int M, int N, int K)
{
    std::uint32_t threads_x = 256;
    std::uint32_t threads_y = 1;
    std::uint32_t workgroups_x = (N/32) * threads_x;
    std::uint32_t workgroups_y = (M/32) * threads_y;

    KernelArguments args;
    args.append(gpuC);
    args.append(gpuA);
    args.append(gpuB);
    args.append(M);
    args.append(N);
    args.append(K);
    args.append(K/32);
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

    err = hipExtModuleLaunchKernel(func, workgroups_x, workgroups_y, 1, threads_x, threads_y, 1, 1000 * sizeof(float), nullptr, nullptr, launchArgs);

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
void GPUMatMul(std::vector<float>& C, std::vector<T>& A, std::vector<T>& B, int M, int N, int K)
{
    hipDevice_t dev{};
    auto err = hipDeviceGet(&dev, 0);

    float* gpuC = nullptr;
    T*     gpuA = nullptr;
    T*     gpuB = nullptr;
    err = hipMalloc(&gpuC, sizeof(float) * M * N);
    err = hipMalloc(&gpuA, sizeof(T) * K * M);
    err = hipMalloc(&gpuB, sizeof(T) * K * N);

    err = hipMemset(gpuC, 0, sizeof(float) * M * N);

    err = hipMemcpyHtoD(gpuA, A.data(), sizeof(T) * K * M);
    err = hipMemcpyHtoD(gpuB, B.data(), sizeof(T) * K * N);

    hipModule_t module{};
    hipFunction_t func{};

    err = prepareASMKernel("MatMul", "matmul.co", &module, &func);
    if (err)
        std::cout << "find asm kernel failed" << std::endl;

    err = launchASMMatMul(func, gpuC, gpuA, gpuB, M, N, K);
    if (err)
        std::cout << "launchASMMatMul error : " << err << std::endl;

    err = hipMemcpyDtoH(C.data(), gpuC, sizeof(float) * M * N);

    err = hipModuleUnload(module);
    err = hipFree(gpuC);
    err = hipFree(gpuA);
    err = hipFree(gpuB);
}

template <typename T>
bool validate(const std::vector<T>& cpuR, const std::vector<T>& cpuC, int M, int N)
{
    for (int n=0; n<N; n++)
    {
        for (int m=0 ; m<M; m++)
        {
            float err = std::abs(float(cpuR[m+n*M]) - float(cpuC[m+n*M]));
            if (err > 1e-5)
            {
                std::cerr << "FAIL: m " << m << " n " << n << " Diff " << err << " Ref " << float(cpuR[m+n*M]) << " GPU " << cpuC[m+n*M] << std::endl;
                return false;
            }
        }
    }
    std::cout << "PASS" << std::endl;
    return true;
}

template <typename T>
bool Sample(const std::uint32_t M, const std::uint32_t N, const std::uint32_t K)
{
    assert(M % 32 == 0 && "M should be the multiple of 32");
    assert(N % 32 == 0 &&  "N should be the multiple of 32");
    assert(K % 64 == 0 && "K should be the multiple of 64");

    std::vector<float> cpuR(M * N, 0.0f);
    std::vector<float> cpuC(M * N, 0.0f);
    std::vector<T> cpuA(K * M);
    std::vector<T> cpuB(K * N);

    initialization(cpuA, K, M);
    initialization(cpuB, K, N);

    CPUMatMul(cpuR, cpuA, cpuB, M, N, K);
    GPUMatMul(cpuC, cpuA, cpuB, M, N, K);

    dumpBuffer("A", cpuA, K, M);
    dumpBuffer("B", cpuB, K, N);
    dumpBuffer("C", cpuC, M, N);
    dumpBuffer("R", cpuR, M, N);

    std::cout << "M, N, K = " << M << ", " << N << ", " << K << std::endl;
    return validate(cpuR, cpuC, M, N);
}

int main(int argc, char **argv) {

    if (argc != 1)
    {
        std::cout << "./matmul" << std::endl;
        return -1;
    }

    if (Sample<__hip_fp8_e4m3_fnuz>(32, 32, 64)== false) {return -1;}
    if (Sample<__hip_fp8_e4m3_fnuz>(512, 32, 128)== false) {return -1;}
    if (Sample<__hip_fp8_e4m3_fnuz>(32, 512, 128)== false) {return -1;}
    if (Sample<__hip_fp8_e4m3_fnuz>(256, 256, 1024) == false) {return -1;}
    if (Sample<__hip_fp8_e4m3_fnuz>(64, 128, 256) == false) {return -1;}
    if (Sample<__hip_fp8_e4m3_fnuz>(128, 64, 64)== false) {return -1;}

    return 0;

}
