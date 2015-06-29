
classdef SpreadingStericMassActionBinding < BindingModel
    %SPREADINGSTERICMASSACTIONBINDING Represents the Spreading Steric Mass Action isotherm by providing its parameters and helper functions
    % Provides the parameters of the Spreading Steric Mass Action isotherm along with the methods to validate and convert them to
    % the types specified in the CADET file format.
    %
    % Copyright: © 2008-2015 Eric von Lieres, Joel Andersson, Andreas Püttmann, Sebastian Schnittert, Samuel Leweke
    %            See the license note at the end of the file.
    
    methods
        
        function obj = SpreadingStericMassActionBinding()
            %SPREADINGSTERICMASSACTIONADSORPTION Constructs a SpreadingStericMassAction object
            obj.name = 'SPREADING_STERIC_MASS_ACTION';
            obj.parameters = cell(11,1);

            obj.parameters{1} = BindingModel.createParameter('SPRSMA_KA1', 'KA1', true);
            obj.parameters{2} = BindingModel.createParameter('SPRSMA_KD1', 'KD1', true);
            obj.parameters{3} = BindingModel.createParameter('SPRSMA_KA2', 'KA2', true);
            obj.parameters{4} = BindingModel.createParameter('SPRSMA_KD2', 'KD2', true);
            obj.parameters{5} = BindingModel.createParameter('SPRSMA_NU1', 'NU1', true);
            obj.parameters{6} = BindingModel.createParameter('SPRSMA_NU2', 'NU2', true);
            obj.parameters{7} = BindingModel.createParameter('SPRSMA_SIGMA1', 'SIGMA1', true);
            obj.parameters{8} = BindingModel.createParameter('SPRSMA_SIGMA2', 'SIGMA2', true);
            obj.parameters{9} = BindingModel.createParameter('SPRSMA_K12', 'K12', true);
            obj.parameters{10} = BindingModel.createParameter('SPRSMA_K21', 'K21', true);
            obj.parameters{11} = BindingModel.createParameter('SPRSMA_LAMBDA', 'LAMBDA', false);
        end
                
        function ok = checkParameters(obj, params, nComponents)
            %CHECKPARAMETERS Checks the values of the given parameters for plausibility
            %
            % Parameters: 
            %   - params: Struct with parameters as fields
            %
            % Returns: True if the values are ok, otherwise false

            if (mod(nComponents, 2) ~= 1)
%                disp(['For emulated second bound state the number of components must be divisible by two (got ' num2str(nComponents) ')'])
                disp(['For emulated second bound state the number of components must be odd (got ' num2str(nComponents) ')'])
                ok = false;
            else
                ok = true;
            end

%            nRealComps = nComponents / 2;
            nRealComps = (nComponents+1) / 2;

            ok = BindingModel.checkNonnegativeVector(params.SPRSMA_KA1, nRealComps, 'SPRSMA_KA1') && ok;
            ok = BindingModel.checkNonnegativeVector(params.SPRSMA_KA2, nRealComps, 'SPRSMA_KA2') && ok;
            ok = BindingModel.checkNonnegativeVector(params.SPRSMA_NU1, nRealComps, 'SPRSMA_NU1') && ok;
            ok = BindingModel.checkNonnegativeVector(params.SPRSMA_SIGMA1, nRealComps, 'SPRSMA_SIGMA1') && ok;
            ok = BindingModel.checkNonnegativeVector(params.SPRSMA_NU2, nRealComps, 'SPRSMA_NU2') && ok;
            ok = BindingModel.checkNonnegativeVector(params.SPRSMA_SIGMA2, nRealComps, 'SPRSMA_SIGMA2') && ok;
            ok = BindingModel.checkNonnegativeVector(params.SPRSMA_K12, nRealComps, 'SPRSMA_K12') && ok;
            ok = BindingModel.checkNonnegativeVector(params.SPRSMA_K21, nRealComps, 'SPRSMA_K21') && ok;
            ok = BindingModel.checkNonnegativeVector(params.SPRSMA_LAMBDA, 1, 'SPRSMA_LAMBDA') && ok;
        end
        
    end

end

% =============================================================================
%  CADET - The Chromatography Analysis and Design Toolkit
%  
%  Copyright © 2008-2015: Eric von Lieres¹, Joel Andersson,
%                         Andreas Puettmann¹, Sebastian Schnittert¹,
%                         Samuel Leweke¹
%                                      
%    ¹ Forschungszentrum Juelich GmbH, IBG-1, Juelich, Germany.
%  
%  All rights reserved. This program and the accompanying materials
%  are made available under the terms of the GNU Public License v3.0 (or, at
%  your option, any later version) which accompanies this distribution, and
%  is available at http://www.gnu.org/licenses/gpl.html
% =============================================================================
