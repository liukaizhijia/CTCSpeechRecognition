require 'nn'
------------------------------------------------------------------------
--[[ CTCCriterion ]]--
-- CTC Alignment for sequence data where input and labels do not align.
-- Useful for speech recognition on a phoneme/character level basis.
-- Inputs assumed are in the form of batch x time x inputdim.
-- Targets assumed in the form of {{1,2},{3,4}} where {1,2} is for the first
-- element.
------------------------------------------------------------------------
local CTCCriterion, parent = torch.class('nn.CTCCriterionTest', 'nn.Criterion')

CTCCriterion.dim = 2

function CTCCriterion:__init()
    parent.__init(self)
    require 'warp_ctc'
    self.acts = torch.Tensor()
    self.convertedGradients = torch.Tensor()
end

function CTCCriterion:updateOutput(output, labels)
    assert(output:nDimension() == CTCCriterion.dim, "Output must be a tensor of (batch * time x inputdim), recieved " .. output:nDimension() .. " dimensions")
    local tensorSizes = output:size()
    local acts = output
    local sizes = torch.Tensor(#labels):fill(tensorSizes[1] / #labels)
    sizes = torch.totable(sizes)
    if (output:type() == 'torch.CudaTensor') then
        local grads = torch.CudaTensor()
        self.output = sumCosts(gpu_ctc(acts, grads, labels, sizes))
    else
        local grads = torch.Tensor()
        self.output = sumCosts(cpu_ctc(acts:float(), grads:float(), labels, sizes))
    end
    return self.output
end

function CTCCriterion:updateGradInput(output, labels)
    local tensorSizes = output:size()
    local acts = output
    local sizes = torch.Tensor(#labels):fill(tensorSizes[1] / #labels)
    sizes = torch.totable(sizes)
    local grads = acts:clone():zero()
    if (output:type() == 'torch.CudaTensor') then
        gpu_ctc(acts, grads, labels, sizes)
    else
        grads = grads:float()
        cpu_ctc(acts:float(), grads, labels, sizes)
    end
    self.gradInput = grads:typeAs(output)
    return self.gradInput
end

--If batching occurs multiple costs are returned. We sum the costs and return.
function sumCosts(list)
    local acc
    for k, v in ipairs(list) do
        if 1 == k then
            acc = v
        else
            acc = acc + v
        end
    end
    return acc
end